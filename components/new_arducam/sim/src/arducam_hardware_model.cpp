#include <arducam_hardware_model.hpp>
#include <arducam_42_data_provider.hpp>

#include <ItcLogger/Logger.hpp>

#include <boost/property_tree/xml_parser.hpp>
#include <sys/stat.h>

namespace Nos3
{
    REGISTER_HARDWARE_MODEL(ArducamHardwareModel,"ARDUCAM_OV5640");

    extern ItcLogger::Logger *sim_logger;

    const std::string ArducamHardwareModel::_arducam_stream_name = "arducam_stream";

    ArducamHardwareModel::ArducamHardwareModel(const boost::property_tree::ptree& config) : SimIHardwareModel(config), _stream_counter(0)
    {
        sim_logger->trace("ArducamHardwareModel::ArducamHardwareModel:  Constructor executing");

        // Time node
        std::string connection_string = config.get("common.nos-connection-string", "tcp://0.0.0.0:12001"); // Get the NOS engine connection string, needed for the busses
        sim_logger->info("ArducamHardwareModel::ArducamHardwareModel:  NOS Engine connection string: %s.", connection_string.c_str());

        /* vvv 1. Get a data provider */
        /* !!! If your sim does not *need* a data provider, delete this block. */
        std::string dp_name = config.get("simulator.hardware-model.data-provider.type", "ARDUCAM_PROVIDER");
        _arducam_dp = SimDataProviderFactory::Instance().Create(dp_name, config);
        sim_logger->info("ArducamHardwareModel::ArducamHardwareModel:  Data provider %s created.", dp_name.c_str());
        /* ^^^ 1. Get a data provider */

        /* vvv 2. Get on the computer bus */
        /* !!! This block is fine for UART.  If you use a different bus type, change this, but most of the structure will be similar. !!! */
/* THE DEFAULT SETUP; PROBABLY NOT USEFUL OR OF INTEREST
        std::string time_bus_name = "command"; // Initialize to default in case value not found in config file
        if (config.get_child_optional("simulator.hardware-model.connections")) 
        {
            BOOST_FOREACH(const boost::property_tree::ptree::value_type &v, config.get_child("simulator.hardware-model.connections")) // Loop through the connections for *this* hw model
            {
                if (v.second.get("type", "").compare("time") == 0) // v.second is the child tree (v.first is the name of the child)
                {
                    time_bus_name = v.second.get("bus-name", "command");
                    break; // Found it... don't need to go through any more items
                }
            }
        }
        _uart_connection.reset(new NosEngine::Uart::Uart(_hub, config.get("simulator.name", "arducam_sim"), connection_string, bus_name));
        _uart_connection->open(node_port);
        sim_logger->info("ArducamHardwareModel::ArducamHardwareModel:  Now on UART bus name %s, port %d.", bus_name.c_str(), node_port);
*/
 
        // Initialize Register
        memset(spi_register, 0, sizeof(spi_register));

        // Connect to Science I2C Bus
        std::string i2c_bus_name = "i2c_2";
        int i2c_bus_address = 60; //0x3C
        _i2c_slave_connection = new I2CSlaveConnection(this, i2c_bus_address, connection_string, i2c_bus_name);

        // Connect to SPI Bus
        std::string spi_bus_name = "spi_0";
        int chip_select = 0;
        _spi_slave_connection = new SpiSlaveConnection(this, chip_select, connection_string, spi_bus_name);
        /* ^^^ 2. Get on the computer bus */
        /* vvv !!! User tip:  You should implement a read callback if you need to handle unsolicited byte messages on your bus and provide byte responses. !!! */
//        _uart_connection->set_read_callback(std::bind(&ArducamHardwareModel::uart_read_callback, this, std::placeholders::_1, std::placeholders::_2));

        /* vvv 3. Streaming data */
        /* !!! If your sim does not *stream* data, delete this entire block. */
        /* vvv !!! Add streaming data functions !!! USER TIP:  Add names and functions to stream data based on what your hardware can stream here */
        _streaming_data_function_map.insert(std::map<std::string, streaming_data_func>::value_type(_arducam_stream_name, &ArducamHardwareModel::create_arducam_data));
        /* ^^^ !!! Add streaming data functions !!! USER TIP:  Add names and functions to stream data based on what your hardware can stream here */

        /* Which streaming data functions are initially enabled should be set in the config file... which will be processed here. !!! DO NOT CHANGE BELOW.  */
        if (config.get_child_optional("simulator.hardware-model.default-streams")) 
        {
            BOOST_FOREACH(const boost::property_tree::ptree::value_type &v, config.get_child("simulator.hardware-model.default-streams")) // Loop through the default streams for *this* hw model
            {
                std::string stream_name = v.second.get("name", "");
                double initial_stream_time = v.second.get("initial-stream-time", 1.0); // Delta from start time to begin streaming
                std::uint32_t stream_period_ms = v.second.get("stream-period-ms", 1); // Time in milliseconds between streamed messages

                if ((_streaming_data_function_map.find(stream_name) != _streaming_data_function_map.end()) &&
                    (stream_period_ms > 0)) {
                    _periodic_streams.insert(
                        std::map<std::string, boost::tuple<double, double>>::value_type(
                            stream_name, boost::tuple<double, double>(_absolute_start_time + initial_stream_time, ((double)stream_period_ms)/1000.0)));

                    sim_logger->info("ArducamHardwareModel::ArducamHardwareModel:  Created default stream name %s starting at %f (start time + %f) with stream period %d milliseconds.", 
                        stream_name.c_str(), _absolute_start_time + initial_stream_time, initial_stream_time, stream_period_ms);
                } else {
                    sim_logger->error("ArducamHardwareModel::ArducamHardwareModel:  Invalid stream name %s or stream period (must be > 0) %d.", 
                        stream_name.c_str(), stream_period_ms);
                }
            }
        }

        std::string time_bus_name = "command"; // Initialize to default in case value not found in config file
        if (config.get_child_optional("hardware-model.connections")) 
        {
            BOOST_FOREACH(const boost::property_tree::ptree::value_type &v, config.get_child("hardware-model.connections")) // Loop through the connections for *this* hw model
            {
                if (v.second.get("type", "").compare("time") == 0) // v.second is the child tree (v.first is the name of the child)
                {
                    time_bus_name = v.second.get("bus-name", "command");
                    break; // Found it... don't need to go through any more items
                }
            }
        }
        _time_bus.reset(new NosEngine::Client::Bus(_hub, connection_string, time_bus_name));
        _time_bus->add_time_tick_callback(std::bind(&ArducamHardwareModel::send_streaming_data, this, std::placeholders::_1));
        sim_logger->info("ArducamHardwareModel::ArducamHardwareModel:  Now on time bus %s, executing callback to stream data.", time_bus_name.c_str());
        /* ^^^ 3. Streaming data */
    }

    // vvv Pretty standard... only change me if a different bus type is used and/or the data provider is not needed
    ArducamHardwareModel::~ArducamHardwareModel(void)
    {        
        sim_logger->trace("ArducamHardwareModel::ArducamHardwareModel:  Destructor executing");
        // 1. Close the I2C
        delete _i2c_slave_connection;
        _i2c_slave_connection = nullptr;

        // 2. Close the SPI
        delete _spi_slave_connection;
        _spi_slave_connection = nullptr;

        // 3. Clean up the data provider we got
        delete _arducam_dp;
        _arducam_dp = nullptr;
    
        // 4. Clean up File Pointer
        if(fin.is_open())
        {
            fin.close();
        }

        // 5. Don't need to clean up the time node, the bus will do it
    }

    // vvv Automagically set up by the base class to be called
    void ArducamHardwareModel::command_callback(NosEngine::Common::Message msg)
    {
        // Here's how to get the data out of the message
        NosEngine::Common::DataBufferOverlay dbf(const_cast<NosEngine::Utility::Buffer&>(msg.buffer));
        sim_logger->info("ArducamHardwareModel::command_callback:  Received command: %s.", dbf.data);

        // Do something with the data
        std::string command = dbf.data;
        std::string response = "ArducamHardwareModel::command_callback:  INVALID COMMAND! (Try STOP ARDUCAMSIM)";
        boost::to_upper(command);
        if (command.compare("STOP ARDUCAMSIM") == 0) 
        {
            _keep_running = false;
            response = "ArducamHardwareModel::command_callback:  STOPPING ARDUCAM";
        }
        // !!! USER TIP: Add anything additional to do with received data here

        // Here's how to send a reply
        _command_node->send_reply_message_async(msg, response.size(), response.c_str());
    }

    // vvv !!! Do not change me
    void ArducamHardwareModel::send_streaming_data(NosEngine::Common::SimTime time)
    {
        const boost::shared_ptr<ArducamDataPoint> data_point =
            boost::dynamic_pointer_cast<ArducamDataPoint>(_arducam_dp->get_data_point());

        std::vector<uint8_t> data;

        double abs_time = _absolute_start_time + (double(time * _sim_microseconds_per_tick)) / 1000000.0;

        for (std::map<std::string, boost::tuple<double, double>>::iterator it = _periodic_streams.begin(); it != _periodic_streams.end(); it++) {
            boost::tuple<double, double> value = it->second;
            double prev_time = boost::tuples::get<0>(value);
            double period = boost::tuples::get<1>(value);
            double next_time = prev_time + period - (_sim_microseconds_per_tick / 1000000.0) / 2; // within half a tick time period
            if (next_time < abs_time) { // Time to send more data
                it->second = boost::tuple<double, double>(abs_time, period);
                std::map<std::string, streaming_data_func>::iterator search = _streaming_data_function_map.find(it->first);
                if (search != _streaming_data_function_map.end()) {
                    streaming_data_func f = search->second;
                    (this->*f)(*data_point, data);
                    sim_logger->debug("send_streaming_data:  Data point:  %s\n", data_point->to_string().c_str());
                    sim_logger->debug("send_streaming_data:  Writing data to UART:  %s\n", uint8_vector_to_hex_string(data).c_str());
//                    _uart_connection->write(&data[0], data.size());
                }
            }
        }
    }

    // USER TIP:  This is your custom function to create some kind of data to send... you can have 1 or more of these functions... 
    // they can be called in response to a request, or periodically if streaming
    void ArducamHardwareModel::create_arducam_data(const ArducamDataPoint& data_point, std::vector<uint8_t>& out_data)
    {
        out_data.resize(14, 0x00);
        // Streaming data header - 0xDEAD
        out_data[0] = 0xDE;
        out_data[1] = 0xAD;
        // Set Payload - Counter
        _stream_counter++;
        out_data[2] = (_stream_counter >> 24) & 0x000000FF; 
        out_data[3] = (_stream_counter >> 16) & 0x000000FF; 
        out_data[4] = (_stream_counter >>  8) & 0x000000FF; 
        out_data[5] = _stream_counter & 0x000000FF;
        // Set Payload - Data

        // floating point numbers are **extremely** problematic (https://docs.oracle.com/cd/E19957-01/806-3568/ncg_goldberg.html),
        // and most hardware transmits some type of unsigned integer (e.g. from an ADC) anyway, 
        // so that's what this arducam is going to do... so scale each of the x, y, z (which are in the range [-1.0, 1.0]) by 32767
        // and add 32768 so that the result fits in a 16 bit unsigned integer... finally, we are going to model the hardware as sending
        // the bytes big endian (most significant byte first)
        // ... this is a good example of the type of thinking you need to do in the hardware model to make its byte interface behave
        // **just like** the real thing... most of the time you will have to **undo** (invert) the calculations the hardware spec says
        // to do to convert from raw units to engineering units

        // Another point how does your hardware behave if the dynamic/environmental data is not valid? 
        // ... you can check this value and make a decision:  data_point.is_arducam_data_valid()
        // ... in this case we are going to pretend that the hardware just pushes forward with whatever
        // it has and the computer on the other end has to deal with detecting invalid data

        uint16_t x   = (uint16_t)(data_point.get_arducam_data_x()*32767.0 + 32768.0);
        out_data[6]  = (x >> 8) & 0x00FF;
        out_data[7]  =  x       & 0x00FF;
        uint16_t y   = (uint16_t)(data_point.get_arducam_data_y()*32767.0 + 32768.0);
        out_data[8]  = (y >> 8) & 0x00FF;
        out_data[9]  =  y       & 0x00FF;
        uint16_t z   = (uint16_t)(data_point.get_arducam_data_z()*32767.0 + 32768.0);
        out_data[10] = (z >> 8) & 0x00FF;
        out_data[11] =  z       & 0x00FF;

        // Streaming data trailer - 0xBEEF
        out_data[12] = 0xBE;
        out_data[13] = 0xEF;
    }

    void ArducamHardwareModel::run(void)
    {
        int i = 0;
        boost::shared_ptr<SimIDataPoint> dp;
        while(_keep_running) 
        {
            sim_logger->info("ArducamHardwareModel::run:  Loop count %d, time %f", i++,
                _absolute_start_time + (double(_time_bus->get_time() * _sim_microseconds_per_tick)) / 1000000.0);
            dp = _arducam_dp->get_data_point();
            sleep(5);
        }
    }

    std::uint8_t ArducamHardwareModel::determine_i2c_response_for_request(const std::vector<uint8_t>& in_data)
    {
        // Initialize local variables
        std::uint8_t out_data = 0x00;

        // Which register?
        switch (in_data[1])
        {             
            case 0x0A:
                out_data = 0x56;
                break;
            
            case 0x0B:
                out_data = 0x40;
                break;

            default:
                break;
        }

        return out_data;
    }

    std::uint16_t ArducamHardwareModel::determine_spi_response_for_request(const std::vector<uint8_t>& in_data)
    {
        // Initialize local variables
        std::uint16_t out_data = 0x0000;
        std::uint8_t reg = (in_data[0] & 0x7F);
        struct stat st;

        // Check write bit
        if ((in_data[0] & 0x80) == 0x80)
        {
            // Process register
            switch (reg)
            {   
                case 0x01: // Capture Control
                    // Number of frames to be captures
                    break;

                case 0x02: // Start capture
                    if(!fin.is_open())
                    {
                        fin.open("cam.bin", std::ios::binary | std::ios::in);
                        sim_logger->debug("Opening cam.bin");
                    }
                    fin.clear();
                    fin.seekg(0, std::ios::beg);
                    // Determine file size
                    if (stat("cam.bin", &st) != 0)
                    {
                        fifo_length = 0;
                        sim_logger->error("ArducamHardwareModel::determine_spi_response_for_request: ERROR - get fifo length failure!");
                    }
                    else
                    {
                        fifo_length = st.st_size;
                    };

                    break;

                case 0x03: // Sensor Interface Timing
                    break;

                case 0x04: // FIFO Control
                    break;

                case 0x05: // GPIO Direction
                    break;
                
                case 0x06: // GPIO Write
                    break;

                default:
                    break;
            }
            spi_register[reg] = in_data[1];            
        }

        // Set out data
        switch (reg)
        {
            case 0x3C:  // Burst FIFO Read
                sim_logger->error("ArducamHardwareModel::determine_spi_response_for_request: ERROR - burst FIFO read not supported!");
                break;

            case 0x3D:  // Single FIFO Read
                out_data = spi_register[reg] << 8;
                if (!fin.eof())
                {
                    fin.read(reinterpret_cast<char*>(&spi_register[reg]), 1);
                }
                break;

            case 0x40:  // ArduChip Version
                out_data = out_data | 0x4000; // 0x40 for 2MP Model
                break;

            case 0x41:  // Capture Done Flag
                out_data = out_data | 0x0800;
                break;

            // Reserved
            case 0x3B:
            case 0x3E:
            case 0x3F:
                sim_logger->error("ERROR - attempted access of reserved register!");
                break;

            case 0x42:  // Camera write FIFO size [7:0]
                out_data = fifo_length >> 8;
                break;
            case 0x43:  // Camera write FIFO size [15:8]
                out_data = fifo_length;
                break;
            case 0x44:  // Camera write FIFO size [18:16]
                out_data = fifo_length << 8;
                break;

            // TODO: Unimplemented
            case 0x02:
            
            case 0x45:  // GPIO Read Register

            default:
                out_data = (spi_register[reg] << 8) | spi_register[reg];
                break;
        }

        return out_data;
    }



    I2CSlaveConnection::I2CSlaveConnection(ArducamHardwareModel* hm,
        int bus_address, std::string connection_string, std::string bus_name)
        : NosEngine::I2C::I2CSlave(bus_address, connection_string, bus_name)
    {
        _hardware_model = hm;
    }

    size_t I2CSlaveConnection::i2c_read(uint8_t *rbuf, size_t rlen)
    {
        size_t num_read;
        sim_logger->debug("i2c_read: 0x%02x", _i2c_out_data); // log data
        if(rlen <= 1)
        {
            rbuf[0] = _i2c_out_data;
            num_read = 1;
        }
        return num_read;
    }

    size_t I2CSlaveConnection::i2c_write(const uint8_t *wbuf, size_t wlen)
    {
        std::vector<uint8_t> in_data(wbuf, wbuf + wlen);
        sim_logger->debug("i2c_write: %s",
            SimIHardwareModel::uint8_vector_to_hex_string(in_data).c_str()); // log data
        _i2c_out_data = _hardware_model->determine_i2c_response_for_request(in_data);
        return wlen;
    }

    SpiSlaveConnection::SpiSlaveConnection(ArducamHardwareModel* hm,
        int chip_select, std::string connection_string, std::string bus_name)
        : NosEngine::Spi::SpiSlave(chip_select, connection_string, bus_name)
    {
        _hardware_model = hm;
    }

    size_t SpiSlaveConnection::spi_read(uint8_t *rbuf, size_t rlen)
    {     
        sim_logger->debug("spi_read: 0x%04x", _spi_out_data); // log data
        //sim_logger->debug("spi_read: rlen = 0x%02x", rlen);
        
        if(rlen <= 2)
        {
            rbuf[0] = (_spi_out_data & 0x00FF);
            rbuf[1] = (_spi_out_data & 0xFF00) >> 8;
        }

        //sim_logger->debug("spi_read: rbuf[0] = 0x%02x", rbuf[0]);
        //sim_logger->debug("spi_read: rbuf[1] = 0x%02x", rbuf[1]);
        return rlen;
    }

    size_t SpiSlaveConnection::spi_write(const uint8_t *wbuf, size_t wlen)
    {
        std::vector<uint8_t> in_data(wbuf, wbuf + wlen);
        sim_logger->debug("spi_write: %s",
            SimIHardwareModel::uint8_vector_to_hex_string(in_data).c_str()); // log data
        _spi_out_data = _hardware_model->determine_spi_response_for_request(in_data);
        return wlen;
    }

/* I SUSPECT THAT THE FOLLOWING IS NOT RELEVANT OR OF INTEREST FOR THE ARDUCAM; IT WAS THE DEFAULT
    // USER TIP:  This is your custom function to do something when you receive unsolicited data from the UART
    void ArducamHardwareModel::uart_read_callback(const uint8_t *buf, size_t len)
    {
        // Retrieve data and log received data in man readable format
        boost::shared_ptr<ArducamDataPoint> data_point;
        std::vector<uint8_t> in_data(buf, buf + len);
        sim_logger->debug("ArducamHardwareModel::uart_read_callback:  REQUEST %s",
            SimIHardwareModel::uint8_vector_to_hex_string(in_data).c_str());
        std::vector<uint8_t> out_data = in_data; // Initialize to just echo back what came in

        // Check if message is incorrect size
        if (in_data.size() != 13)
        {
            sim_logger->debug("ArducamHardwareModel::uart_read_callback:  Invalid command size of %d received!", in_data.size());
            return;
        }

        // Check header - 0xDEAD
        if ((in_data[0] != 0xDE) || (in_data[1] !=0xAD))
        {
            sim_logger->debug("ArducamHardwareModel::uart_read_callback:  Header incorrect!");
            return;
        }

        // Check trailer - 0xBEEF
        if ((in_data[11] != 0xBE) || (in_data[12] !=0xEF))
        {
            sim_logger->debug("ArducamHardwareModel::uart_read_callback:  Trailer incorrect!");
            return;
        }

        // Process command type
        switch (in_data[6])
        {
            case 1:
                sim_logger->debug("ArducamHardwareModel::uart_read_callback:  Send data command received!");
                data_point = boost::dynamic_pointer_cast<ArducamDataPoint>(_arducam_dp->get_data_point());
                sim_logger->debug("ArducamHardwareModel::uart_read_callback:  Data point:  %s", data_point->to_string().c_str());
                create_arducam_data(*data_point, out_data); // Command not echoed back... actual arducam data is sent
                break;

            case 2:
                sim_logger->debug("ArducamHardwareModel::uart_read_callback:  Configuration command received!");
                if ((in_data[2] == _arducam_stream_name[0]) && 
                    (in_data[3] == _arducam_stream_name[1]) && 
                    (in_data[4] == _arducam_stream_name[2]) && 
                    (in_data[5] == _arducam_stream_name[3])) { 
                    // ... this is a good example of the type of thinking you need to do in the hardware model to make its byte interface behave
                    // **just like** the real thing... understand exactly what order the bytes come over the wire, what type they represent, and
                    // how to put them back together in the correct way to the correct type:
                    uint32_t millisecond_stream_delay = ((uint32_t)in_data[7] << 24) +
                                                        ((uint32_t)in_data[8] << 16) +
                                                        ((uint32_t)in_data[9] << 8 ) +
                                                        ((uint32_t)in_data[10]);
                    std::map<std::string, boost::tuple<double, double>>::iterator it = _periodic_streams.find(_arducam_stream_name);
                    if ((it != _periodic_streams.end()) &&
                        (millisecond_stream_delay > 0)) {
                        boost::get<1>(it->second) = ((double)millisecond_stream_delay)/1000.0;
                        sim_logger->debug("ArducamHardwareModel::uart_read_callback:  New millisecond stream delay for %s of %u", 
                            _arducam_stream_name.c_str(), millisecond_stream_delay);
                    } else {
                        sim_logger->error("ArducamHardwareModel::uart_read_callback:  Stream %s was not set to be executed periodically or delay %u was not > 0",
                            _arducam_stream_name.c_str(), millisecond_stream_delay);
                        // zero out the response data... to indicate invalid request
                        in_data[ 7] = 0;
                        in_data[ 8] = 0;
                        in_data[ 9] = 0;
                        in_data[10] = 0;
                    }
                } else {
                    sim_logger->error("ArducamHardwareModel::uart_read_callback:  Requested stream %c%c%c%c does not match prefix of %s", 
                        in_data[3], in_data[4], in_data[5], in_data[6], _arducam_stream_name.c_str());
                    // zero out the response data... to indicate invalid request
                    in_data[ 7] = 0;
                    in_data[ 8] = 0;
                    in_data[ 9] = 0;
                    in_data[10] = 0;
                }
                out_data = in_data; // Echo back what was actually configured
                break;

            case 3:
                sim_logger->debug("ArducamHardwareModel::uart_read_callback:  Other command received!");
                break;
            
            default:
                sim_logger->debug("ArducamHardwareModel::uart_read_callback:  Unused command received!");
                break;
        }

        // Log reply data in man readable format and ship the message bytes off
        sim_logger->debug("ArducamHardwareModel::uart_read_callback:  REPLY %s",
            SimIHardwareModel::uint8_vector_to_hex_string(out_data).c_str());
        _uart_connection->write(&out_data[0], out_data.size());
    }
*/
}
