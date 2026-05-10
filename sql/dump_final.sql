-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Хост: 127.0.0.1
-- Время создания: Май 11 2026 г., 01:40
-- Версия сервера: 10.4.32-MariaDB
-- Версия PHP: 8.2.12

SET FOREIGN_KEY_CHECKS=0;
SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- База данных: `controlorderdb`
--
CREATE DATABASE IF NOT EXISTS `controlorderdb` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
USE `controlorderdb`;

DELIMITER $$
--
-- Процедуры
--
DROP PROCEDURE IF EXISTS `sp_change_order_status`$$
CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_change_order_status` (IN `p_order_id` INT, IN `p_new_status_id` INT)   BEGIN
    DECLARE v_order_number VARCHAR(20);
    
    UPDATE orders 
    SET status_id = p_new_status_id
    WHERE order_id = p_order_id;
    
    SELECT order_number INTO v_order_number FROM orders WHERE order_id = p_order_id;
    
    SELECT CONCAT('Статус заказа ', v_order_number, ' изменён') AS message;
END$$

DROP PROCEDURE IF EXISTS `sp_create_order`$$
CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_create_order` (IN `p_client_id` INT, IN `p_manager_id` INT, IN `p_order_date` DATETIME, IN `p_status_id` INT)   BEGIN
    DECLARE new_order_number VARCHAR(20);
    DECLARE next_id INT;
    
    SELECT IFNULL(MAX(order_id), 0) + 1 INTO next_id FROM orders;
    SET new_order_number = CONCAT('ORD-', LPAD(next_id, 3, '0'));
    
    INSERT INTO orders (order_number, order_date, client_id, manager_id, status_id)
    VALUES (new_order_number, p_order_date, p_client_id, p_manager_id, p_status_id);
    
    SELECT LAST_INSERT_ID() AS new_order_id;
END$$

DROP PROCEDURE IF EXISTS `sp_get_client_orders`$$
CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_get_client_orders` (IN `p_client_id` INT)   BEGIN
    SELECT 
        o.order_number,
        o.order_date,
        s.status_name,
        SUM(oi.quantity * oi.unit_price) AS total_amount
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    JOIN statuses s ON o.status_id = s.status_id
    WHERE o.client_id = p_client_id
    GROUP BY o.order_id, o.order_number, o.order_date, s.status_name
    ORDER BY o.order_date DESC;
END$$

DELIMITER ;

-- --------------------------------------------------------

--
-- Структура таблицы `orders`
--

DROP TABLE IF EXISTS `orders`;
CREATE TABLE IF NOT EXISTS `orders` (
  `order_id` int(11) NOT NULL AUTO_INCREMENT,
  `order_number` varchar(20) NOT NULL,
  `order_date` datetime NOT NULL,
  `client_id` int(11) NOT NULL,
  `manager_id` int(11) NOT NULL,
  `status_id` int(11) NOT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`order_id`),
  UNIQUE KEY `order_number` (`order_number`),
  KEY `client_id` (`client_id`),
  KEY `manager_id` (`manager_id`),
  KEY `status_id` (`status_id`)
) ENGINE=InnoDB AUTO_INCREMENT=30 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- ССЫЛКИ ТАБЛИЦЫ `orders`:
--   `client_id`
--       `users` -> `user_id`
--   `manager_id`
--       `users` -> `user_id`
--   `status_id`
--       `statuses` -> `status_id`
--

--
-- Очистить таблицу перед добавлением данных `orders`
--

TRUNCATE TABLE `orders`;
--
-- Дамп данных таблицы `orders`
--

INSERT INTO `orders` (`order_id`, `order_number`, `order_date`, `client_id`, `manager_id`, `status_id`, `created_at`, `updated_at`) VALUES
(1, 'ORD-001', '2025-05-01 10:30:00', 1, 3, 4, '2026-05-08 22:46:35', '2026-05-10 16:49:15'),
(2, 'ORD-002', '2025-05-02 14:15:00', 2, 3, 2, '2026-05-08 22:46:35', '2026-05-10 01:03:30'),
(3, 'ORD-003', '2025-05-03 09:00:00', 1, 3, 3, '2026-05-08 22:46:35', '2026-05-08 22:46:35'),
(4, 'ORD-004', '2026-05-09 02:48:01', 1, 3, 1, '2026-05-09 02:48:01', '2026-05-09 02:48:47'),
(27, 'ORD-005', '2026-05-10 16:34:06', 13, 3, 4, '2026-05-10 16:34:06', '2026-05-10 16:35:55'),
(28, 'ORD-028', '2026-05-10 16:34:51', 13, 3, 4, '2026-05-10 16:34:51', '2026-05-10 16:36:12'),
(29, 'ORD-029', '2026-05-10 16:37:25', 13, 3, 4, '2026-05-10 16:37:25', '2026-05-10 17:01:47');

--
-- Триггеры `orders`
--
DROP TRIGGER IF EXISTS `trg_orders_before_update`;
DELIMITER $$
CREATE TRIGGER `trg_orders_before_update` BEFORE UPDATE ON `orders` FOR EACH ROW BEGIN
    IF OLD.status_id = 3 AND NEW.status_id = 4 THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Нельзя отменить уже выданный заказ';
    END IF;
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Структура таблицы `order_items`
--

DROP TABLE IF EXISTS `order_items`;
CREATE TABLE IF NOT EXISTS `order_items` (
  `order_item_id` int(11) NOT NULL AUTO_INCREMENT,
  `order_id` int(11) NOT NULL,
  `product_id` int(11) NOT NULL,
  `quantity` int(11) NOT NULL,
  `unit_price` decimal(10,2) NOT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`order_item_id`),
  UNIQUE KEY `uq_order_product` (`order_id`,`product_id`),
  KEY `product_id` (`product_id`)
) ;

--
-- ССЫЛКИ ТАБЛИЦЫ `order_items`:
--   `order_id`
--       `orders` -> `order_id`
--   `product_id`
--       `products` -> `product_id`
--

--
-- Очистить таблицу перед добавлением данных `order_items`
--

TRUNCATE TABLE `order_items`;
--
-- Дамп данных таблицы `order_items`
--

INSERT INTO `order_items` (`order_item_id`, `order_id`, `product_id`, `quantity`, `unit_price`, `created_at`) VALUES
(134, 1, 1, 1, 50000.00, '2026-05-10 12:08:35'),
(135, 1, 3, 1, 3000.00, '2026-05-10 12:08:35'),
(136, 1, 2, 1, 1500.00, '2026-05-10 12:08:35'),
(157, 29, 1, 1, 50000.00, '2026-05-10 16:37:25'),
(158, 29, 2, 1, 1500.00, '2026-05-10 16:37:25'),
(159, 29, 3, 1, 3000.00, '2026-05-10 16:37:25');

--
-- Триггеры `order_items`
--
DROP TRIGGER IF EXISTS `trg_check_quantity_before_insert`;
DELIMITER $$
CREATE TRIGGER `trg_check_quantity_before_insert` BEFORE INSERT ON `order_items` FOR EACH ROW BEGIN
    DECLARE stock INT;
    
    SELECT quantity INTO stock FROM products WHERE product_id = NEW.product_id;
    
    IF NEW.quantity > stock THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Недостаточно товара на складе';
    END IF;
END
$$
DELIMITER ;
DROP TRIGGER IF EXISTS `trg_check_quantity_before_update`;
DELIMITER $$
CREATE TRIGGER `trg_check_quantity_before_update` BEFORE UPDATE ON `order_items` FOR EACH ROW BEGIN
    DECLARE stock INT;

    SELECT quantity
    INTO stock
    FROM products
    WHERE product_id = NEW.product_id;

    IF NEW.quantity > stock THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Недостаточно товара на складе';
    END IF;
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Структура таблицы `products`
--

DROP TABLE IF EXISTS `products`;
CREATE TABLE IF NOT EXISTS `products` (
  `product_id` int(11) NOT NULL AUTO_INCREMENT,
  `product_name` varchar(100) NOT NULL,
  `description` text DEFAULT NULL,
  `price` decimal(10,2) NOT NULL,
  `quantity` int(11) NOT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`product_id`)
) ENGINE=InnoDB AUTO_INCREMENT=6 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- ССЫЛКИ ТАБЛИЦЫ `products`:
--

--
-- Очистить таблицу перед добавлением данных `products`
--

TRUNCATE TABLE `products`;
--
-- Дамп данных таблицы `products`
--

INSERT INTO `products` (`product_id`, `product_name`, `description`, `price`, `quantity`, `created_at`) VALUES
(1, 'Ноутбук Lenovo IdeaPad 3', '15.6\" FHD, Ryzen 5, 8GB RAM, 256GB SSD', 50000.00, 10, '2026-05-08 22:46:35'),
(2, 'Мышь Logitech M170', 'Беспроводная, 2.4 ГГц', 1500.00, 10, '2026-05-08 22:46:35'),
(3, 'Клавиатура Logitech K380', 'Компактная, Bluetooth', 3000.00, 10, '2026-05-08 22:46:35'),
(4, 'Монитор Samsung LS27A', '27\", IPS, 75Hz', 18000.00, 10, '2026-05-08 22:46:35');

-- --------------------------------------------------------

--
-- Структура таблицы `statuses`
--

DROP TABLE IF EXISTS `statuses`;
CREATE TABLE IF NOT EXISTS `statuses` (
  `status_id` int(11) NOT NULL AUTO_INCREMENT,
  `status_name` varchar(30) NOT NULL,
  PRIMARY KEY (`status_id`),
  UNIQUE KEY `status_name` (`status_name`)
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- ССЫЛКИ ТАБЛИЦЫ `statuses`:
--

--
-- Очистить таблицу перед добавлением данных `statuses`
--

TRUNCATE TABLE `statuses`;
--
-- Дамп данных таблицы `statuses`
--

INSERT INTO `statuses` (`status_id`, `status_name`) VALUES
(2, 'В обработке'),
(3, 'Выдан'),
(1, 'Новый'),
(4, 'Отменён');

-- --------------------------------------------------------

--
-- Структура таблицы `users`
--

DROP TABLE IF EXISTS `users`;
CREATE TABLE IF NOT EXISTS `users` (
  `user_id` int(11) NOT NULL AUTO_INCREMENT,
  `login` varchar(50) NOT NULL,
  `email` varchar(100) NOT NULL,
  `password_hash` varchar(64) NOT NULL,
  `password_salt` varchar(32) NOT NULL,
  `role` enum('admin','manager','client') NOT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`user_id`),
  UNIQUE KEY `login` (`login`),
  UNIQUE KEY `email` (`email`)
) ENGINE=InnoDB AUTO_INCREMENT=15 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- ССЫЛКИ ТАБЛИЦЫ `users`:
--

--
-- Очистить таблицу перед добавлением данных `users`
--

TRUNCATE TABLE `users`;
--
-- Дамп данных таблицы `users`
--

INSERT INTO `users` (`user_id`, `login`, `email`, `password_hash`, `password_salt`, `role`, `created_at`, `updated_at`) VALUES
(1, 'Inav123', 'ivanov123@gmail.com', 'temp_hash_1', 'temp_salt_1', 'client', '2026-05-08 22:46:35', '2026-05-08 23:20:47'),
(2, 'Dext', 'DextPetya@yandex.ru', 'temp_hash_2', 'temp_salt_2', 'client', '2026-05-08 22:46:35', '2026-05-08 23:20:47'),
(3, 'GrindMr1', 'alexpetrov@mail.ru', 'temp_hash_3', 'temp_salt_3', 'manager', '2026-05-08 22:46:35', '2026-05-10 01:09:08'),
(4, 'AdPers2', 'misha005@mail.ru', 'temp_hash_4', 'temp_salt_4', 'admin', '2026-05-08 22:46:35', '2026-05-08 23:20:47'),
(10, '123', '123', '931b5fa8b52ab1740d5fe38d11fc44d784779f7f317a6e22a24c31f4002a982c', '7fecc792fcb0d1981581e1db68151933', 'client', '2026-05-09 22:44:41', '2026-05-09 22:44:41'),
(11, 'destro1d', 'destro1d@gmail.com', '0edcd1ba1adade191cfa2b0f0fa0eead89eda59edd4959cd5e720e1a325a60f8', '275519772c8eb021918c86030e0ab675', 'admin', '2026-05-09 22:49:33', '2026-05-10 01:09:48'),
(12, 'nevermiss', 'nevermiss@yandex.ru', 'c80d094466039d38bc3ae305be84261f01e9b61ec883e4d4b1b37272814a4a7e', '55ac77be6992e98bb6076bb4b0808e10', 'manager', '2026-05-09 22:49:54', '2026-05-10 01:09:41'),
(13, 'Maxim1337', '@mail.ru', 'b2c9a1b9e3245ca93df21cd87d54fdbe25f8c1a80fca88dc3e17b60e9d04a000', 'fff2cddfa218f0ab1dc3232abb173270', 'client', '2026-05-09 22:50:25', '2026-05-09 22:50:25');

-- --------------------------------------------------------

--
-- Дублирующая структура для представления `v_manager_stats`
-- (См. Ниже фактическое представление)
--
DROP VIEW IF EXISTS `v_manager_stats`;
CREATE TABLE IF NOT EXISTS `v_manager_stats` (
`user_id` int(11)
,`manager_login` varchar(50)
,`total_orders` bigint(21)
,`completed_orders` decimal(22,0)
,`total_amount` decimal(42,2)
,`avg_order_amount` decimal(10,2)
);

-- --------------------------------------------------------

--
-- Дублирующая структура для представления `v_orders_info`
-- (См. Ниже фактическое представление)
--
DROP VIEW IF EXISTS `v_orders_info`;
CREATE TABLE IF NOT EXISTS `v_orders_info` (
`order_id` int(11)
,`order_number` varchar(20)
,`order_date` datetime
,`client_login` varchar(50)
,`manager_login` varchar(50)
,`status_name` varchar(30)
,`created_at` datetime
,`updated_at` datetime
);

-- --------------------------------------------------------

--
-- Структура для представления `v_manager_stats`
--
DROP TABLE IF EXISTS `v_manager_stats`;

DROP VIEW IF EXISTS `v_manager_stats`;
CREATE OR REPLACE VIEW `v_manager_stats`  AS SELECT `u`.`user_id` AS `user_id`, `u`.`login` AS `manager_login`, count(distinct `o`.`order_id`) AS `total_orders`, sum(case when `s`.`status_name` = 'Выдан' then 1 else 0 end) AS `completed_orders`, sum(`oi`.`quantity` * `oi`.`unit_price`) AS `total_amount`, cast(avg(`oi`.`quantity` * `oi`.`unit_price`) as decimal(10,2)) AS `avg_order_amount` FROM (((`users` `u` left join `orders` `o` on(`u`.`user_id` = `o`.`manager_id`)) left join `statuses` `s` on(`o`.`status_id` = `s`.`status_id`)) left join `order_items` `oi` on(`o`.`order_id` = `oi`.`order_id`)) WHERE `u`.`role` = 'manager' GROUP BY `u`.`user_id`, `u`.`login` ;

-- --------------------------------------------------------

--
-- Структура для представления `v_orders_info`
--
DROP TABLE IF EXISTS `v_orders_info`;

DROP VIEW IF EXISTS `v_orders_info`;
CREATE OR REPLACE VIEW `v_orders_info`  AS SELECT `o`.`order_id` AS `order_id`, `o`.`order_number` AS `order_number`, `o`.`order_date` AS `order_date`, `u1`.`login` AS `client_login`, `u2`.`login` AS `manager_login`, `s`.`status_name` AS `status_name`, `o`.`created_at` AS `created_at`, `o`.`updated_at` AS `updated_at` FROM (((`orders` `o` join `users` `u1` on(`o`.`client_id` = `u1`.`user_id`)) join `users` `u2` on(`o`.`manager_id` = `u2`.`user_id`)) join `statuses` `s` on(`o`.`status_id` = `s`.`status_id`)) ;

--
-- Ограничения внешнего ключа сохраненных таблиц
--

--
-- Ограничения внешнего ключа таблицы `orders`
--
ALTER TABLE `orders`
  ADD CONSTRAINT `orders_ibfk_1` FOREIGN KEY (`client_id`) REFERENCES `users` (`user_id`),
  ADD CONSTRAINT `orders_ibfk_2` FOREIGN KEY (`manager_id`) REFERENCES `users` (`user_id`),
  ADD CONSTRAINT `orders_ibfk_3` FOREIGN KEY (`status_id`) REFERENCES `statuses` (`status_id`);

--
-- Ограничения внешнего ключа таблицы `order_items`
--
ALTER TABLE `order_items`
  ADD CONSTRAINT `order_items_ibfk_1` FOREIGN KEY (`order_id`) REFERENCES `orders` (`order_id`),
  ADD CONSTRAINT `order_items_ibfk_2` FOREIGN KEY (`product_id`) REFERENCES `products` (`product_id`);
SET FOREIGN_KEY_CHECKS=1;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
