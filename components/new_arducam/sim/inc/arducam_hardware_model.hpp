#ifndef NOS3_ARDUCAMHARDWAREMODEL_HPP
#define NOS3_ARDUCAMHARDWAREMODEL_HPP

#include <map>

#include <boost/tuple/tuple.hpp>
#include <boost/property_tree/ptree.hpp>

#include <atomic>
#include <fstream>

#include <sim_i_data_provider.hpp>
#include <arducam_data_point.hpp>
#include <sim_i_hardware_model.hpp>

#include <Client/Bus.hpp>

// Protocols
#include <I2C/Client/I2CSlave.hpp>
#include <Spi/Client/SpiSlave.hpp>

namespace Nos3
{
    // vvv This is pretty standard for a hardware model
    class ArducamHardwareModel : public SimIHardwareModel
    {
    public:
        // Constructors / destructor
        ArducamHardwareModel(const boost::property_tree::ptree& config);
        ~ArducamHardwareModel(void);
        void run(void);
        std::uint8_t determine_i2c_response_for_request(const std::vector<uint8_t>& in_data);
        std::uint16_t determine_spi_response_for_request(const std::vector<uint8_t>& in_data);

    private:
        // Private helper methods
        void uart_read_callback(const uint8_t *buf, size_t len); // This guy handles unsolicited bytes the hardware receives from its peripheral bus
        void send_streaming_data(NosEngine::Common::SimTime time); // This guy provides an example of how to send unsolicited streaming data
        void create_arducam_data(const ArducamDataPoint& data_point, std::vector<uint8_t>& out_data); // This guy creates data to send from a data point
        void command_callback(NosEngine::Common::Message msg);  // This guy handles out of band commands to the sim on the command bus

        std::atomic<bool>                                   _keep_running;
        // Private data members
        class I2CSlaveConnection*                           _i2c_slave_connection;
        class SpiSlaveConnection*                           _spi_slave_connection;
        std::unique_ptr<NosEngine::Client::Bus>             _time_bus;

        SimIDataProvider*                                   _arducam_dp;
        std::uint8_t                                        spi_register[69]; //0x45
        std::ifstream                                       fin;
        std::uint32_t                                       fifo_length;

        // vvv Standard maps needed to set up streaming
        typedef void (ArducamHardwareModel::*streaming_data_func)(const ArducamDataPoint&, std::vector<uint8_t>&); // Convenience pointer to function typedef
        std::map<std::string, streaming_data_func>          _streaming_data_function_map; // stream name, function to call to generate data for that stream
        std::map<std::string, boost::tuple<double, double>> _periodic_streams; // stream name, (last absolute time function was called, period (seconds) to call function)

        // vvv Internal state data... change me as appropriate for your hardware model
        std::uint32_t                                       _stream_counter; // Used in this example to keep some internal state to report during streaming
        static const std::string                            _arducam_stream_name; // Used in this example to validate commands sent over UART to this hardware model sim
    };

    class I2CSlaveConnection : public NosEngine::I2C::I2CSlave
    {
    public:
        I2CSlaveConnection(ArducamHardwareModel* hm, int bus_address, std::string connection_string, std::string bus_name);
        size_t i2c_read(uint8_t *rbuf, size_t rlen);
        size_t i2c_write(const uint8_t *wbuf, size_t wlen);
    private:
        ArducamHardwareModel* _hardware_model;
        std::uint8_t _i2c_out_data;
    };

    class SpiSlaveConnection : public NosEngine::Spi::SpiSlave
    {
    public:
        SpiSlaveConnection(ArducamHardwareModel* hm, int chip_select, std::string connection_string, std::string bus_name);
        size_t spi_read(uint8_t *rbuf, size_t rlen);
        size_t spi_write(const uint8_t *wbuf, size_t wlen);
    private:
        ArducamHardwareModel* _hardware_model;
        std::uint16_t _spi_out_data;        
    };

}

#endif
