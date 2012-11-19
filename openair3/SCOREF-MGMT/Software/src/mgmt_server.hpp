/*******************************************************************************

  Eurecom OpenAirInterface
  Copyright(c) 1999 - 2012 Eurecom

  This program is free software; you can redistribute it and/or modify it
  under the terms and conditions of the GNU General Public License,
  version 2, as published by the Free Software Foundation.

  This program is distributed in the hope it will be useful, but WITHOUT
  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
  more details.

  You should have received a copy of the GNU General Public License along with
  this program; if not, write to the Free Software Foundation, Inc.,
  51 Franklin St - Fifth Floor, Boston, MA 02110-1301 USA.

  The full GNU General Public License is included in this distribution in
  the file called "COPYING".

  Contact Information
  Openair Admin: openair_admin@eurecom.fr
  Openair Tech : openair_tech@eurecom.fr
  Forums       : http://forums.eurecom.fsr/openairinterface
  Address      : Eurecom, 2229, route des crêtes, 06560 Valbonne Sophia Antipolis, France

*******************************************************************************/

/*!
 * \file mgmt_server.hpp
 * \brief This is where everything begins and ends
 * \company EURECOM
 * \date 2012
 * \author Baris Demiray
 * \email: baris.demiray@eurecom.fr
 * \note none
 * \bug none
 * \warning none
*/

#ifndef MGMT_SERVER_H_
#define MGMT_SERVER_H_

#include "mgmt_information_base.hpp"
#include "mgmt_packet_handler.hpp"
#include "mgmt_client_manager.hpp"
#include "util/mgmt_log.hpp"
#include <boost/asio.hpp>
#include <vector>
using boost::asio::ip::udp;

namespace ba = boost::asio;

/**
 * Management server functionality and a wrapper for boost::asio's asynchronous I/O
 */
class ManagementServer {
	public:
		/**
		 * Receive buffer size in bytes
		 */
		static const u_int16_t RX_BUFFER_SIZE = 1024;
		/**
		 * Transmit sbuffer size in bytes
		 */
		static const u_int16_t TX_BUFFER_SIZE = 1024;

	public:
		/**
		 * Constructor for ManagementServer class
		 *
		 * @param ioService I/O functionality is passed by the caller
		 * @param portNumber UDP port number that will be listened/connected to
		 * @param mib ManagementInformationBase reference
		 * @param logger Logger object reference for logging purposes
		 */
		ManagementServer(ba::io_service& ioService, u_int16_t portNumber, ManagementInformationBase& mib, ManagementClientManager& clientManager, Logger& logger);
		/**
		 * Destructor for ManagementServer class
		 */
		~ManagementServer();

	public:
		/**
		 * Receive data
		 */
		void readData();

		/**
		 * Callback for Rx, so called when data is read on the socket
		 *
		 * @param errorCode Error code
		 * @param size Amount of data available
		 */
		void handleReceive(const boost::system::error_code& errorCode, size_t size);
		/**
		 * Handles incoming Management data, called by handleReceive()
		 *
		 * @param none
		 * @return none
		 */
		void handleClientData();
		/**
		 * Callback for Tx, so called when data is written onto the socket
		 *
		 * @param errorCode Error code
		 * @param size Amount of data to be sent
		 */
		void handleSend(const boost::system::error_code& errorCode, size_t size);

	private:
		/**
		 * The io_service object that the datagram socket will use to dispatch
		 * handlers for any asynchronous operation performed on the socket
		 */
		boost::asio::io_service& ioService;
		/**
		 * udp::socket object
		 */
		boost::asio::ip::udp::socket socket;
		/**
		 * UDP connection's recipient
		 */
		boost::asio::ip::udp::endpoint recipient;
		/**
		 * RX buffer
		 */
		vector<unsigned char> rxData;
		/**
		 * TX buffer
		 */
		vector<unsigned char> txData;
		/**
		 * Management Information Base reference
		 */
		ManagementInformationBase& mib;
		/**
		 * Client manager
		 */
		ManagementClientManager& clientManager;
		/**
		 * Logger object reference for logging purposes
		 */
		Logger& logger;
		/**
		 * Response packets are generated using PacketHandler class
		 */
		PacketHandler packetHandler;
};

#endif /* MGMT_SERVER_H_ */