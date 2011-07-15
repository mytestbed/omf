-- phpMyAdmin SQL Dump
-- version 3.3.10deb1
-- http://www.phpmyadmin.net
--
-- Host: localhost
-- Generation Time: Jul 15, 2011 at 12:42 PM
-- Server version: 5.1.54
-- PHP Version: 5.3.5-1ubuntu7.2

SET SQL_MODE="NO_AUTO_VALUE_ON_ZERO";

--
-- Database: `inventory`
--

-- --------------------------------------------------------

--
-- Table structure for table `devices`
--

CREATE TABLE IF NOT EXISTS `devices` (
  `id` int(11) NOT NULL COMMENT 'universally unique id for device',
  `device_kind_id` int(11) NOT NULL COMMENT 'link to corresponding entry in device_kinds',
  `motherboard_id` int(11) DEFAULT NULL COMMENT 'link to corresponding entry in motherboards',
  `inventory_id` int(11) NOT NULL COMMENT 'link to corresponding entry in inventories',
  `address` varchar(18) NOT NULL COMMENT 'bus address of this device.  MUST sort lexically by bus',
  `mac` varchar(17) DEFAULT NULL COMMENT 'MAC address of this device, if it is a network device',
  `canonical_name` varchar(64) DEFAULT NULL COMMENT 'a good guess as to the name Linux will give to this device',
  PRIMARY KEY (`id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Dumping data for table `devices`
--

INSERT INTO `devices` (`id`, `device_kind_id`, `motherboard_id`, `inventory_id`, `address`, `mac`, `canonical_name`) VALUES
(1, 1, 1, 1, 'Bogus 00:01', '00:03:2D:08:1A:33', 'control'),
(2, 1, 2, 1, 'Bogus 00:01', '00:03:2D:08:1A:23', 'control'),
(3, 1, 3, 1, 'Bogus 00:01', '00:03:2D:0C:FC:B1', 'control'),
(4, 1, 4, 1, 'Bogus 00:01', '00:03:2D:08:1A:17', 'control');

-- --------------------------------------------------------

--
-- Table structure for table `device_kinds`
--

CREATE TABLE IF NOT EXISTS `device_kinds` (
  `id` int(11) NOT NULL COMMENT 'universally unique id for device',
  `inventory_id` int(11) NOT NULL COMMENT 'the inventory when we caught this device type',
  `bus` varchar(16) DEFAULT NULL COMMENT 'e.g. pci or usb',
  `vendor` int(11) NOT NULL COMMENT 'id of vendor from /sys',
  `device` int(11) NOT NULL COMMENT 'id of device from /sys',
  PRIMARY KEY (`id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Dumping data for table `device_kinds`
--


-- --------------------------------------------------------

--
-- Table structure for table `device_ouis`
--

CREATE TABLE IF NOT EXISTS `device_ouis` (
  `oui` char(8) NOT NULL COMMENT 'OUI as string XX:XX:XX',
  `device_kind_id` int(11) NOT NULL COMMENT 'link to corresponding entry in device_kinds',
  `inventory_id` int(11) DEFAULT NULL COMMENT 'if generated automatically, id of inventory run, otherwise NULL'
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Dumping data for table `device_ouis`
--


-- --------------------------------------------------------

--
-- Table structure for table `device_tags`
--

CREATE TABLE IF NOT EXISTS `device_tags` (
  `tag` varchar(64) NOT NULL COMMENT 'name for this tag',
  `device_kind_id` int(11) NOT NULL COMMENT 'link to corresponding entry in device_kinds',
  `inventory_id` int(11) DEFAULT NULL COMMENT 'if generated automatically, id of inventory run, otherwise NULL'
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Dumping data for table `device_tags`
--


-- --------------------------------------------------------

--
-- Table structure for table `inventories`
--

CREATE TABLE IF NOT EXISTS `inventories` (
  `id` int(11) NOT NULL COMMENT 'obligatiory unique id',
  `opened` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'start of inventory run',
  `closed` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00' COMMENT 'end of inventory run, or 0000-etc. if not done yet',
  PRIMARY KEY (`id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Dumping data for table `inventories`
--

INSERT INTO `inventories` (`id`, `opened`, `closed`) VALUES
(1, '2008-08-28 20:45:12', '0000-00-00 00:00:00');

-- --------------------------------------------------------

--
-- Table structure for table `locations`
--

CREATE TABLE IF NOT EXISTS `locations` (
  `id` int(11) NOT NULL COMMENT 'universally unique id for location',
  `name` varchar(64) DEFAULT NULL,
  `x` int(11) NOT NULL DEFAULT '0' COMMENT 'logical x address of location',
  `y` int(11) NOT NULL DEFAULT '0' COMMENT 'logical y address of location',
  `z` int(11) NOT NULL DEFAULT '0' COMMENT 'logical z address of location',
  `latitude` float DEFAULT NULL COMMENT 'latitude of this location or NULL',
  `longitude` float DEFAULT NULL COMMENT 'longitude of this location or NULL',
  `elevation` float DEFAULT NULL COMMENT 'elevation of this location or NULL',
  `switch_ip` varchar(15) NOT NULL,
  `switch_port` int(11) NOT NULL,
  `testbed_id` int(11) NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Dumping data for table `locations`
--

INSERT INTO `locations` (`id`, `name`, `x`, `y`, `z`, `latitude`, `longitude`, `elevation`, `switch_ip`, `switch_port`, `testbed_id`) VALUES
(1, 'L4 south', 1, 1, 1, NULL, NULL, NULL, '10.0.0.201', 1, 1),
(2, 'L4 south', 1, 2, 1, NULL, NULL, NULL, '10.0.0.201', 2, 1),
(3, 'L4 south', 1, 3, 1, NULL, NULL, NULL, '10.0.0.201', 3, 1),
(4, 'L4 south', 1, 4, 1, NULL, NULL, NULL, '10.0.0.201', 4, 1);

-- --------------------------------------------------------

--
-- Table structure for table `motherboards`
--

CREATE TABLE IF NOT EXISTS `motherboards` (
  `id` int(11) NOT NULL COMMENT 'universally unique id for motherboard',
  `inventory_id` int(11) NOT NULL COMMENT 'link to corresponding entry in inventories',
  `mfr_sn` varchar(128) DEFAULT NULL COMMENT 'manufacturer serial number of the motherboard',
  `cpu_type` varchar(64) DEFAULT NULL COMMENT 'name of CPU as given by vendor',
  `cpu_n` int(11) DEFAULT NULL COMMENT 'number of CPUs',
  `cpu_hz` float DEFAULT NULL COMMENT 'CPU speed in MHz',
  `hd_sn` varchar(64) DEFAULT NULL COMMENT 'hard drive serial number, NULL if no hd',
  `hd_size` int(11) DEFAULT NULL COMMENT 'hard disk size in bytes',
  `hd_status` tinyint(1) DEFAULT '1' COMMENT 'true means drive probably okay',
  `memory` int(11) DEFAULT NULL COMMENT 'memory size in bytes',
  PRIMARY KEY (`id`),
  UNIQUE KEY `mfr_sn` (`mfr_sn`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Dumping data for table `motherboards`
--

INSERT INTO `motherboards` (`id`, `inventory_id`, `mfr_sn`, `cpu_type`, `cpu_n`, `cpu_hz`, `hd_sn`, `hd_size`, `hd_status`, `memory`) VALUES
(1, 1, NULL, NULL, 1, NULL, NULL, NULL, 1, NULL),
(2, 1, NULL, NULL, 1, NULL, NULL, NULL, 1, NULL),
(3, 1, NULL, NULL, 1, NULL, NULL, NULL, 1, NULL),
(4, 1, NULL, NULL, 1, NULL, NULL, NULL, 1, NULL);

-- --------------------------------------------------------

--
-- Table structure for table `nodes`
--

CREATE TABLE IF NOT EXISTS `nodes` (
  `id` int(11) NOT NULL AUTO_INCREMENT COMMENT 'universally unique id for nodes',
  `control_ip` varchar(15) DEFAULT NULL,
  `control_mac` varchar(17) NOT NULL,
  `cmc_ip` varchar(15) DEFAULT NULL,
  `hostname` varchar(64) DEFAULT NULL,
  `hrn` varchar(128) DEFAULT NULL,
  `inventory_id` int(11) NOT NULL COMMENT 'link to corresponding entry in inventories',
  `chassis_sn` varchar(64) DEFAULT NULL COMMENT 'manufacturer serial number of the chassis of the node; optionally null',
  `motherboard_id` int(11) NOT NULL COMMENT 'the motherboard in this node',
  `location_id` int(11) DEFAULT NULL COMMENT 'the location of this node',
  `pxeimage_id` int(11) DEFAULT NULL,
  `disk` varchar(32) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `location_id` (`location_id`)
) ENGINE=MyISAM  DEFAULT CHARSET=latin1 AUTO_INCREMENT=1333 ;

--
-- Dumping data for table `nodes`
--

INSERT INTO `nodes` (`id`, `control_ip`, `control_mac`, `cmc_ip`, `hostname`, `hrn`, `inventory_id`, `chassis_sn`, `motherboard_id`, `location_id`, `pxeimage_id`, `disk`) VALUES
(1, '10.0.0.1', '00:03:2D:08:1A:33', '172.16.0.1', 'node1', 'omf.nicta.node1', 1, 'BOGUS SN 123', 1, 1, 5, '/dev/sda'),
(2, '10.0.0.2', '00:03:2D:08:1A:23', '172.16.0.2', 'node2', 'omf.nicta.node2', 1, 'BOGUS SN 123', 2, 2, 5, '/dev/sda'),
(3, '10.0.0.3', '00:03:2D:0C:FC:B1', '172.16.0.3', 'node3', 'omf.nicta.node3', 1, 'BOGUS SN 123', 3, 3, 5, '/dev/sda'),
(4, '10.0.0.4', '00:03:2D:08:1A:17', '172.16.0.4', 'node4', 'omf.nicta.node4', 1, 'BOGUS SN 123', 4, 4, 5, '/dev/sda');

-- --------------------------------------------------------

--
-- Table structure for table `pxeimages`
--

CREATE TABLE IF NOT EXISTS `pxeimages` (
  `id` int(11) DEFAULT NULL,
  `image_name` varchar(64) DEFAULT NULL,
  `short_description` varchar(128) DEFAULT NULL
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Dumping data for table `pxeimages`
--

INSERT INTO `pxeimages` (`id`, `image_name`, `short_description`) VALUES
(4, 'omf-5.3.1', '5.3.1 testing'),
(5, 'omf-5.3', '5.3 PXE image');

-- --------------------------------------------------------

--
-- Table structure for table `testbeds`
--

CREATE TABLE IF NOT EXISTS `testbeds` (
  `id` int(11) NOT NULL AUTO_INCREMENT COMMENT 'universally unique id for testbed',
  `name` varchar(128) NOT NULL COMMENT 'example: grid',
  PRIMARY KEY (`id`),
  UNIQUE KEY `node_domain` (`name`)
) ENGINE=MyISAM  DEFAULT CHARSET=latin1 AUTO_INCREMENT=31 ;

--
-- Dumping data for table `testbeds`
--

INSERT INTO `testbeds` (`id`, `name`) VALUES
(1, 'norbit');

