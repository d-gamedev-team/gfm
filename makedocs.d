#!/usr/bin/env rdmd

import std.algorithm;
import std.exception;
import std.file;
import std.json;
import std.path;
import std.process;
import std.range;
import std.regex;
import std.stdio;
import std.string;
import std.traits;

string stripCommas(string jsonSrc)
{
    return jsonSrc.replaceAll(ctRegex!(r",(\s+[}\]])", "m"), "$1");
}

auto getSubpackages()
{
    return "../dub.json"
        .readText
        .stripCommas
        .parseJSON["subPackages"]
        .array
        .map!(x => x["name"].str)
    ;
}

string[] getImportPaths(Range)(Range subpackages)
{
    string[] importPaths;
    string parentPath = getcwd.buildNormalizedPath("..");
    
    foreach(pkg; subpackages)
        importPaths ~= runDub(["describe", "gfm:" ~ pkg, "--import-paths"]).split("\n");
    
    importPaths = importPaths
        .sort!()
        .uniq
        .filter!(x => !x.empty)
        .filter!(x => !x.canFind(parentPath)) //filter gfm's own import paths
        .array
    ;
    
    return importPaths;
}

string runDub(string[] args)
{
    auto result = execute(["dub"] ~ args, null, Config.none, size_t.max, "..");
    
    if(result.status != 0)
        throw new Exception(
            "`dub %s` exited with code %s".format(
                args.join(" "),
                result.status
            )
        );
    
    return result.output;
}

void copyFolder(string source, string destination)
{
    enforce(source.exists && source.isDir, "Source folder does not exist?!");
    mkdirRecurse(destination);
    
    size_t prefixLength = source
        .pathSplitter
        .array
        .length
    ;
    
    foreach(item; dirEntries(source, SpanMode.breadth))
    {
        string itemRelativePath = item
            .pathSplitter
            .drop(prefixLength)
            .buildPath
        ;
        string itemDestination = destination.buildPath(itemRelativePath);
        
        if(item.isDir)
            mkdirRecurse(itemDestination);
        else
            copy(item, itemDestination);
    }
}

void main(string[] args)
{
    auto subpackages = getSubpackages;
    
    mkdirRecurse("source");
    scope(exit) rmdirRecurse("source");
    
    foreach(pkg; subpackages)
        copyFolder(buildPath("..", pkg), "source");
    
    copy("../index.d", "source/index.d");
    
    string dmdCmd = subpackages
        .getImportPaths
        .map!(x => x.replace(" ", `\ `))
        .map!(x => "-I" ~ x)
        .join(" ")
        .Identity!(x => "dmd " ~ x)
    ;
    string[] generatorArgs = [
        "rdmd",
        "bootDoc/generate.d",
        "source",
        `--dmd=` ~ dmdCmd,
        "--bootdoc=bootDoc",
        "--parallel",
    ] ~ args.drop(1);
    
    writefln("Running `%s`", generatorArgs.join(" "));
    
    Pid pid = generatorArgs.spawnProcess;
    int status = pid.wait;
    
    writeln("Exited with code ", status);
}
