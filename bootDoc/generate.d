#!/usr/bin/env rdmd

import core.atomic;
import core.thread;
import core.sync.mutex;
import std.algorithm;
import std.array;
import std.conv;
import std.exception;
import std.file;
import std.getopt;
import std.parallelism;
import std.path;
import std.process;
import std.range;
import std.regex;
import std.stdio;
import std.string;

struct Module
{
	string filePath, fileBaseName;

	string rootPackage, packageName, moduleName;


	string getFilePath(in char[] root) const
	{
		return filePath ? filePath : format("%s/%s", root, fileBaseName);
	}

	string getGeneratedName(in char[] separator) const
	{
		return fileBaseName.stripExtension().replace("/", separator) ~ ".html";
	}
}

string getPackageDDocFilePath(in char[] packageName, in char[] tempFolder)
{
	return buildPath(tempFolder, packageName ~ ".ddoc");
}

string getPackageDDocFileContent(in char[] packageName)
{
	// Don't place macro definition in the first line because it will be ignored.
	return format("\nTHISPACKAGE=%s\nTHISROOTPACKAGE=%s\n",
		packageName, packageName.findSplitBefore(".")[0]);
}

const(Module)[] parseModuleFile(in string path)
{
	enforce(exists(path), format("Module file could not be found (%s)", path));

	auto modPattern = regex(`\$\(MODULE\s+([^,)]+)`);

	string[] modules;
	foreach(line; File(path).byLine())
	{
		if(auto m = match(line, modPattern))
			modules ~= m.captures[1].idup;
	}

	return modules.map!(name => name.splitter('.').array())()
		.map!(divided => Module(
			null, divided.join("/") ~ ".d",
			divided.length > 1 ? divided[0] : null,
			divided.length > 1 ? divided[0 .. $-1].join(".") : null,
			divided[$-1]
		 ))().array();
}

auto usage = `Generate bootDoc documentation pages for a project
documented with DDoc.

Usage:
%s "path to project root" [options]
Options (defaults in brackets):
  --bootdoc=<path>     path to bootDoc directory
                       (containing the file bootdoc.ddoc). ["bootDoc"]
  --modules=<path>     path to candyDoc-style list of modules.
                       ["modules.ddoc"]
  --settings=<path>    path to settings file. ["settings.ddoc"]
  --separator=<string> package separator for output HTML files. ["."]
  --verbose            print information during the generation process.
  --parallel           generate in parallel mode. Substantially decreases
                       generation speed on multi-core machines.
  --dmd=<string>       name of compiler frontend to use for generation. ["dmd"]
  --extra=<path>       path to extra module. Can be used multiple times.
  --output=<path>      path to output generated files to.

Options not listed above are passed to the D compiler on generation.

Description:
Generates bootDoc-themed DDoc documentation for a list of D modules.
The modules are read from the specified candyDoc-style module list,
as well as taken from any --extra arguments passed. Each module name
is converted to a relative path, which is then searched in the
specified project root.

Example module file:
    MODULES =
        $(MODULE example.example)

Example generation:
    rdmd bootDoc/generate.d .. --separator=_

The above will read modules.ddoc from the working directory,
then generate documentation for all listed modules. The module
example.example is searched for at the path ../example/example.d
and its HTML output is put in example_example.html. The output
is configured with settings.ddoc, read from the working directory.
`;

int main(string[] args)
{
	string bootDoc = "bootDoc";
	string moduleFile = "modules.ddoc";
	string settingsFile = "settings.ddoc";
	string separator = ".";
	string dmd = "dmd";
	bool verbose = false;
	bool parallelMode = false;
	string[] extras;
	string outputDir = ".";

	getopt(args, config.passThrough,
		"bootdoc", &bootDoc,
		"modules", &moduleFile,
		"settings", &settingsFile,
		"separator", &separator,
		"verbose", &verbose,
		"parallel", &parallelMode,
		"dmd", &dmd,
		"extra", (string _, string path){ extras ~= path; },
		"output", &outputDir
	);

	if(args.length < 2)
	{
		writefln(usage, args[0]);
		return 2;
	}

	immutable root = args[1];
	immutable passThrough =
		args.length > 2 ?
		args[2 .. $].map!(arg => format(`"%s"`, arg))().array().join(" ") :
		null;

	immutable bootDocFile = format("%s/bootdoc.ddoc", bootDoc);
	Mutex outputMutex = new Mutex();

	immutable tempFolder = buildPath(tempDir(), "bootDoc-temp" ~ to!string(getpid()));
	try
		rmdirRecurse(tempFolder);
	catch (FileException)
	{
		// Not actually an error.
	}

	mkdir(tempFolder);
	scope(exit) rmdirRecurse(tempFolder);

	immutable byPackageDocFilePrefix = buildPath(tempFolder, "package-");

	int generate(in Module mod)
	{
		auto outputName = buildPath(outputDir, mod.getGeneratedName(separator));

		auto command = format(`%s -c -o- -I"%s" -Df"%s" "%s" "%s" "%s" "%s" `,
			dmd, root, outputName, mod.getFilePath(root), settingsFile, bootDocFile, moduleFile);

		if(mod.packageName)
		{
			command ~= format(`"%s" `, mod.packageName.getPackageDDocFilePath(tempFolder));
		}

		if(passThrough !is null)
		{
			command ~= passThrough;
		}

		if(verbose)
		{
			outputMutex.lock();

			scope (exit)
				outputMutex.unlock();

			writefln("%s => %s\n  [%s]\n", mod.fileBaseName, outputName, command);
		}

		return system(command);
	}

	const modList = parseModuleFile(moduleFile) ~
		extras.map!(name => Module(name, baseName(name)))().array();

	foreach(mod; modList.filter!`a.packageName`())
		std.file.write(
			mod.packageName.getPackageDDocFilePath(tempFolder),
			mod.packageName.getPackageDDocFileContent()
		);

	shared int result;

	if(parallelMode)
	{
		enum workUnitSize = 1;

		foreach(mod; parallel(modList, workUnitSize))
			if (auto res = generate(mod))
				cas(&result, 0, res); // Store the first error encountered.
	}
	else
	{
		foreach(mod; modList)
			if (auto res = generate(mod))
				if (!result) // Store the first error encountered.
					result = res;
	}

	return result;
}
