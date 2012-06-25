module gfm.fann.fann;

import std.string;
import derelict.fann.fann;
import gfm.fann.lib;

// ANN stands for Artificial Neural Network
final class ANN
{
    public
    {
        static ANN createStandard(FANNLib lib, uint[] layers)
        {
            FANN* fann = fann_create_standard_array(layers.length, layers.ptr);
            lib.runtimeCheck();
            assert(fann !is null);
            return new ANN(lib, fann);
        }

        static ANN createSparse(FANNLib lib, float connectionRate, uint[] layers)
        {
            FANN* fann = fann_create_sparse_array(connectionRate, layers.length, layers.ptr);
            lib.runtimeCheck();
            assert(fann !is null);
            return new ANN(lib, fann);
        }

        static ANN createSparse(FANNLib lib, uint[] layers)
        {
            FANN* fann = fann_create_shortcut_array(layers.length, layers.ptr);
            lib.runtimeCheck();
            assert(fann !is null);
            return new ANN(lib, fann);
        }

        static ANN createFromFile(FANNLib lib, string filename)
        {
            FANN* fann = fann_create_from_file(toStringz(filename));
            lib.runtimeCheck();
            assert(fann !is null);
            return new ANN(lib, fann);
        }

        ~this()
        {
            close();
        }
        
        void close()
        {
            if (_fann !is null)
            {
                fann_destroy(_fann);
                _fann = null;
            }
        }

        void save(string filename)
        {
            fann_save(_fann, toStringz(filename));
            _lib.runtimeCheck();
        }

        void saveToFixed(string filename)
        {
            fann_save_to_fixed(_fann, toStringz(filename));
            _lib.runtimeCheck();
        }

        fann_type* run(fann_type*	input)
        {
            fann_type* res = fann_run(_fann, input);
            _lib.runtimeCheck();
            return res;
        }

        void printConnections()
        {
            fann_print_connections(_fann);
        }

        void printParameters()
        {
            fann_print_parameters(_fann);
        }

        void randomizeWeights(fann_type minWeight, fann_type maxWeight)
        {
            fann_randomize_weights(_fann, minWeight, maxWeight);
            _lib.runtimeCheck();
        }

        uint numInputs()
        {
            return fann_get_num_input(_fann);
        }

        uint numOutputs()
        {
            return fann_get_num_output(_fann);
        }

        uint numLayers()
        {
            return fann_get_num_layers(_fann);
        }

        uint totalNeurons()
        {
            return fann_get_total_neurons(_fann);
        }

        uint totalConnections()
        {
            return fann_get_total_connections(_fann);
        }

        network_type_enum networkType()
        {
            return fann_get_network_type(_fann);
        }

        float connectionRate()
        {
            return fann_get_connection_rate(_fann);
        }
    }

    private
    {
        this(FANNLib lib, FANN* fann)
        {
            _lib = lib;
            _fann = fann;
        }

        FANN* _fann;
        FANNLib _lib;
    }
}