-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Servidor: 127.0.0.1
-- Tiempo de generación: 28-05-2025 a las 04:03:36
-- Versión del servidor: 10.4.32-MariaDB
-- Versión de PHP: 8.2.12

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Base de datos: `inventario`
--

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `categoria`
--

CREATE TABLE `categoria` (
  `codigo_categoria` int(11) NOT NULL,
  `nombre_categoria` varchar(50) DEFAULT NULL,
  `statud_categoria` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `categoria`
--

INSERT INTO `categoria` (`codigo_categoria`, `nombre_categoria`, `statud_categoria`) VALUES
(1, 'Electrónicos', 1),
(2, 'Accesorios', 1),
(3, 'Oficina', 1);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `cliente`
--

CREATE TABLE `cliente` (
  `cedula_cliente` varchar(20) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `cliente`
--

INSERT INTO `cliente` (`cedula_cliente`) VALUES
('V-11223344'),
('V-12345678');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `datos_personales`
--

CREATE TABLE `datos_personales` (
  `cedula` varchar(20) NOT NULL,
  `nombre` varchar(50) NOT NULL,
  `apellido` varchar(50) NOT NULL,
  `direccion` varchar(100) DEFAULT NULL,
  `telefono` varchar(15) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `datos_personales`
--

INSERT INTO `datos_personales` (`cedula`, `nombre`, `apellido`, `direccion`, `telefono`) VALUES
('V-11223344', 'Pedro', 'Martínez', 'Av. Bolívar', '04161122334'),
('V-12345678', 'Ana', 'Pérez', 'Av. Libertador', '04141234567'),
('V-87654321', 'Luis', 'Gómez', 'Calle Principal', '04268765432');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `detalle_venta`
--

CREATE TABLE `detalle_venta` (
  `id_detalle` int(11) NOT NULL,
  `codigo_venta` int(11) DEFAULT NULL,
  `codigo_producto` int(11) DEFAULT NULL,
  `cantidad` int(11) DEFAULT NULL,
  `precio_unitario` decimal(10,2) DEFAULT NULL,
  `iva` decimal(10,2) DEFAULT NULL,
  `subtotal_con_iva` decimal(10,2) DEFAULT NULL,
  `subtotal` decimal(10,2) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `detalle_venta`
--

INSERT INTO `detalle_venta` (`id_detalle`, `codigo_venta`, `codigo_producto`, `cantidad`, `precio_unitario`, `iva`, `subtotal_con_iva`, `subtotal`) VALUES
(1, 1, 1, 1, 850.00, 136.00, 986.00, 850.00),
(2, 1, 2, 2, 15.00, 0.00, 30.00, 30.00),
(3, 2, 3, 1, 45.00, 7.20, 52.20, 45.00),
(4, 3, 1, 2, 850.00, 272.00, 1972.00, 1700.00),
(5, 3, 1, 2, 850.00, 272.00, 1972.00, 1700.00);

--
-- Disparadores `detalle_venta`
--
DELIMITER $$
CREATE TRIGGER `trg_actualizar_iva_general` AFTER UPDATE ON `detalle_venta` FOR EACH ROW BEGIN
    -- Recalcular todo el IVA general para la venta
    UPDATE venta v
    SET 
        iva_general = (
            SELECT COALESCE(SUM(iva), 0)
            FROM detalle_venta
            WHERE codigo_venta = NEW.codigo_venta
        ),
        subtotal_sin_iva = (
            SELECT COALESCE(SUM(subtotal), 0)
            FROM detalle_venta
            WHERE codigo_venta = NEW.codigo_venta
        ),
        monto = (
            SELECT COALESCE(SUM(subtotal_con_iva), 0)
            FROM detalle_venta
            WHERE codigo_venta = NEW.codigo_venta
        )
    WHERE v.codigo_venta = NEW.codigo_venta;
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `trg_actualizar_monto_venta` AFTER INSERT ON `detalle_venta` FOR EACH ROW BEGIN
    UPDATE venta v
    SET 
        monto = COALESCE(monto, 0) + NEW.subtotal_con_iva,
        subtotal_sin_iva = COALESCE(subtotal_sin_iva, 0) + NEW.subtotal,
        iva_general = COALESCE(iva_general, 0) + NEW.iva
    WHERE v.codigo_venta = NEW.codigo_venta;
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `trg_calcular_iva_subtotal` BEFORE INSERT ON `detalle_venta` FOR EACH ROW BEGIN
    DECLARE v_precio DECIMAL(10,2);
    DECLARE v_tiene_iva BOOLEAN;

    SELECT precio, tiene_iva INTO v_precio, v_tiene_iva
    FROM productos
    WHERE codigo_producto = NEW.codigo_producto;

    SET NEW.precio_unitario = v_precio;
    SET NEW.subtotal = NEW.cantidad * v_precio;
    SET NEW.iva = IF(v_tiene_iva, NEW.subtotal * 0.16, 0);
    SET NEW.subtotal_con_iva = NEW.subtotal + NEW.iva;
    

END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `trg_precio_producto_insert` BEFORE INSERT ON `detalle_venta` FOR EACH ROW BEGIN
    DECLARE v_precio DECIMAL(10,2);
    
    -- Obtener el precio actual del producto
    SELECT precio INTO v_precio
    FROM productos
    WHERE codigo_producto = NEW.codigo_producto;
    
    -- Forzar el precio del producto, ignorando cualquier valor manual
    SET NEW.precio_unitario = v_precio;
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `trg_precio_producto_update` BEFORE UPDATE ON `detalle_venta` FOR EACH ROW BEGIN
    DECLARE v_precio DECIMAL(10,2);
    
    -- Si se intenta modificar el precio_unitario
    IF NEW.precio_unitario <> OLD.precio_unitario THEN
        -- Obtener el precio actual del producto
        SELECT precio INTO v_precio
        FROM productos
        WHERE codigo_producto = NEW.codigo_producto;
        
        -- Mantener el precio original o actualizar si cambió en productos
        SET NEW.precio_unitario = v_precio;
    END IF;
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `empleado`
--

CREATE TABLE `empleado` (
  `cedula_empleado` varchar(20) NOT NULL,
  `cargo` varchar(50) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `empleado`
--

INSERT INTO `empleado` (`cedula_empleado`, `cargo`) VALUES
('V-87654321', 'Cajero Principal');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `forma_pago`
--

CREATE TABLE `forma_pago` (
  `codigo_forma_pago` int(11) NOT NULL,
  `nombre_forma_pago` varchar(50) NOT NULL,
  `statud_forma_pago` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `forma_pago`
--

INSERT INTO `forma_pago` (`codigo_forma_pago`, `nombre_forma_pago`, `statud_forma_pago`) VALUES
(1, 'Efectivo', 1),
(2, 'Tarjeta de Débito', 1),
(3, 'Tarjeta de Crédito', 1),
(4, 'Transferencia', 1);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `forma_venta`
--

CREATE TABLE `forma_venta` (
  `id_pago_venta` int(11) NOT NULL,
  `codigo_venta` int(11) NOT NULL,
  `codigo_forma_pago` int(11) NOT NULL,
  `monto` decimal(10,2) NOT NULL,
  `vuelto` decimal(10,2) DEFAULT 0.00
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `permisos`
--

CREATE TABLE `permisos` (
  `id_permiso` int(11) NOT NULL,
  `rol` varchar(50) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `permisos`
--

INSERT INTO `permisos` (`id_permiso`, `rol`) VALUES
(1, 'administrador');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `productos`
--

CREATE TABLE `productos` (
  `codigo_productos` int(11) NOT NULL,
  `precio` decimal(10,2) DEFAULT NULL,
  `stock` int(11) DEFAULT NULL,
  `nombre_producto` varchar(50) DEFAULT NULL,
  `descripcion` text DEFAULT NULL,
  `categoria` int(11) DEFAULT NULL,
  `tiene_iva` tinyint(1) DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `productos`
--

INSERT INTO `productos` (`codigo_productos`, `precio`, `stock`, `nombre_producto`, `descripcion`, `categoria`, `tiene_iva`) VALUES
(1, 850.00, 10, 'Laptop HP', NULL, 1, 1),
(2, 15.00, 50, 'Mouse Inalámbrico', NULL, 2, 0),
(3, 45.00, 30, 'Teclado Mecánico', NULL, 2, 1);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `proveedores`
--

CREATE TABLE `proveedores` (
  `rif_proveedor` varchar(13) NOT NULL,
  `nombre_proveedor` varchar(100) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `proveedores`
--

INSERT INTO `proveedores` (`rif_proveedor`, `nombre_proveedor`) VALUES
('J-123456789', 'HP');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `proveedor_producto`
--

CREATE TABLE `proveedor_producto` (
  `id` int(11) NOT NULL,
  `proveedor` varchar(13) NOT NULL,
  `producto` int(11) NOT NULL,
  `precio_compra` decimal(10,2) NOT NULL,
  `statud_proveedor` int(11) DEFAULT 1,
  `cantidad` int(11) DEFAULT NULL,
  `fecha` date DEFAULT NULL,
  `monto_total` decimal(10,2) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `proveedor_producto`
--

INSERT INTO `proveedor_producto` (`id`, `proveedor`, `producto`, `precio_compra`, `statud_proveedor`, `cantidad`, `fecha`, `monto_total`) VALUES
(15, 'J-123456789', 1, 700.00, 3, 2, '2025-05-27', 1400.00);

--
-- Disparadores `proveedor_producto`
--
DELIMITER $$
CREATE TRIGGER `before_proveedor_producto_update` BEFORE INSERT ON `proveedor_producto` FOR EACH ROW BEGIN
    SET NEW.monto_total = NEW.precio_compra * NEW.cantidad;
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `before_proveedor_producto_update_update` BEFORE UPDATE ON `proveedor_producto` FOR EACH ROW BEGIN
    SET NEW.monto_total = NEW.precio_compra * NEW.cantidad;
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `statud`
--

CREATE TABLE `statud` (
  `id_statud` int(11) NOT NULL,
  `nombre` varchar(50) NOT NULL,
  `descripcion` text DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `statud`
--

INSERT INTO `statud` (`id_statud`, `nombre`, `descripcion`) VALUES
(1, 'Activo', 'Registro activo y disponible'),
(2, 'Inactivo', 'Registro deshabilitado temporalmente'),
(3, 'Pendiente', 'Esperando aprobación'),
(4, 'Bloqueado', 'Registro bloqueado por seguridad'),
(5, 'Activo', 'Registro activo y disponible'),
(6, 'Inactivo', 'Registro deshabilitado temporalmente'),
(7, 'Pendiente', 'Esperando aprobación'),
(8, 'Bloqueado', 'Registro bloqueado por seguridad');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `usuario`
--

CREATE TABLE `usuario` (
  `id` int(11) NOT NULL,
  `username` varchar(20) NOT NULL,
  `password` varchar(255) NOT NULL,
  `cedula_usuario` varchar(20) DEFAULT NULL,
  `statud_usuario` int(11) DEFAULT NULL,
  `rol` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `usuario`
--

INSERT INTO `usuario` (`id`, `username`, `password`, `cedula_usuario`, `statud_usuario`, `rol`) VALUES
(1, 'aperez', 'a808872095d4f27c101d5ede9dec2ae8354608f4dbe5e702eb48d7e7c4fe18bf', 'V-87654321', 1, 1);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `venta`
--

CREATE TABLE `venta` (
  `codigo_venta` int(11) NOT NULL,
  `monto` decimal(10,2) DEFAULT 0.00,
  `iva_general` decimal(10,2) DEFAULT 0.00,
  `subtotal_sin_iva` decimal(10,2) DEFAULT 0.00,
  `fecha` date DEFAULT curdate(),
  `cliente` varchar(20) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `venta`
--

INSERT INTO `venta` (`codigo_venta`, `monto`, `iva_general`, `subtotal_sin_iva`, `fecha`, `cliente`) VALUES
(1, 1016.00, 136.00, 880.00, '2025-05-27', 'V-12345678'),
(2, 52.20, 7.20, 45.00, '2025-05-27', 'V-11223344'),
(3, 3944.00, 544.00, 3400.00, '2025-05-27', 'V-11223344');

--
-- Índices para tablas volcadas
--

--
-- Indices de la tabla `categoria`
--
ALTER TABLE `categoria`
  ADD PRIMARY KEY (`codigo_categoria`),
  ADD KEY `fk_categoria_statud` (`statud_categoria`);

--
-- Indices de la tabla `cliente`
--
ALTER TABLE `cliente`
  ADD PRIMARY KEY (`cedula_cliente`);

--
-- Indices de la tabla `datos_personales`
--
ALTER TABLE `datos_personales`
  ADD PRIMARY KEY (`cedula`);

--
-- Indices de la tabla `detalle_venta`
--
ALTER TABLE `detalle_venta`
  ADD PRIMARY KEY (`id_detalle`),
  ADD KEY `fk_detalle_venta` (`codigo_venta`),
  ADD KEY `fk_detalle_producto` (`codigo_producto`);

--
-- Indices de la tabla `empleado`
--
ALTER TABLE `empleado`
  ADD PRIMARY KEY (`cedula_empleado`);

--
-- Indices de la tabla `forma_pago`
--
ALTER TABLE `forma_pago`
  ADD PRIMARY KEY (`codigo_forma_pago`),
  ADD KEY `fk_forma_pago_statud` (`statud_forma_pago`);

--
-- Indices de la tabla `forma_venta`
--
ALTER TABLE `forma_venta`
  ADD PRIMARY KEY (`id_pago_venta`),
  ADD KEY `fk_forma_venta` (`codigo_venta`),
  ADD KEY `fk_forma_pago` (`codigo_forma_pago`);

--
-- Indices de la tabla `permisos`
--
ALTER TABLE `permisos`
  ADD PRIMARY KEY (`id_permiso`);

--
-- Indices de la tabla `productos`
--
ALTER TABLE `productos`
  ADD PRIMARY KEY (`codigo_productos`),
  ADD KEY `fk_producto_categoria` (`categoria`);

--
-- Indices de la tabla `proveedores`
--
ALTER TABLE `proveedores`
  ADD PRIMARY KEY (`rif_proveedor`);

--
-- Indices de la tabla `proveedor_producto`
--
ALTER TABLE `proveedor_producto`
  ADD PRIMARY KEY (`id`),
  ADD KEY `fk_provprod_proveedor` (`proveedor`),
  ADD KEY `fk_provprod_producto` (`producto`),
  ADD KEY `fk_provprod_statud` (`statud_proveedor`);

--
-- Indices de la tabla `statud`
--
ALTER TABLE `statud`
  ADD PRIMARY KEY (`id_statud`);

--
-- Indices de la tabla `usuario`
--
ALTER TABLE `usuario`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `username` (`username`),
  ADD KEY `fk_usuario_empleado` (`cedula_usuario`),
  ADD KEY `fk_usuario_statud` (`statud_usuario`),
  ADD KEY `fk_usuario_permiso` (`rol`);

--
-- Indices de la tabla `venta`
--
ALTER TABLE `venta`
  ADD PRIMARY KEY (`codigo_venta`),
  ADD KEY `fk_venta_cliente` (`cliente`);

--
-- AUTO_INCREMENT de las tablas volcadas
--

--
-- AUTO_INCREMENT de la tabla `categoria`
--
ALTER TABLE `categoria`
  MODIFY `codigo_categoria` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- AUTO_INCREMENT de la tabla `detalle_venta`
--
ALTER TABLE `detalle_venta`
  MODIFY `id_detalle` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=6;

--
-- AUTO_INCREMENT de la tabla `forma_pago`
--
ALTER TABLE `forma_pago`
  MODIFY `codigo_forma_pago` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=5;

--
-- AUTO_INCREMENT de la tabla `forma_venta`
--
ALTER TABLE `forma_venta`
  MODIFY `id_pago_venta` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `permisos`
--
ALTER TABLE `permisos`
  MODIFY `id_permiso` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT de la tabla `productos`
--
ALTER TABLE `productos`
  MODIFY `codigo_productos` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- AUTO_INCREMENT de la tabla `proveedor_producto`
--
ALTER TABLE `proveedor_producto`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=16;

--
-- AUTO_INCREMENT de la tabla `statud`
--
ALTER TABLE `statud`
  MODIFY `id_statud` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=9;

--
-- AUTO_INCREMENT de la tabla `usuario`
--
ALTER TABLE `usuario`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT de la tabla `venta`
--
ALTER TABLE `venta`
  MODIFY `codigo_venta` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- Restricciones para tablas volcadas
--

--
-- Filtros para la tabla `categoria`
--
ALTER TABLE `categoria`
  ADD CONSTRAINT `fk_categoria_statud` FOREIGN KEY (`statud_categoria`) REFERENCES `statud` (`id_statud`);

--
-- Filtros para la tabla `cliente`
--
ALTER TABLE `cliente`
  ADD CONSTRAINT `fk_cliente_datos` FOREIGN KEY (`cedula_cliente`) REFERENCES `datos_personales` (`cedula`);

--
-- Filtros para la tabla `detalle_venta`
--
ALTER TABLE `detalle_venta`
  ADD CONSTRAINT `fk_detalle_producto` FOREIGN KEY (`codigo_producto`) REFERENCES `productos` (`codigo_productos`),
  ADD CONSTRAINT `fk_detalle_venta` FOREIGN KEY (`codigo_venta`) REFERENCES `venta` (`codigo_venta`);

--
-- Filtros para la tabla `empleado`
--
ALTER TABLE `empleado`
  ADD CONSTRAINT `fk_empleado_datos` FOREIGN KEY (`cedula_empleado`) REFERENCES `datos_personales` (`cedula`);

--
-- Filtros para la tabla `forma_pago`
--
ALTER TABLE `forma_pago`
  ADD CONSTRAINT `fk_forma_pago_statud` FOREIGN KEY (`statud_forma_pago`) REFERENCES `statud` (`id_statud`);

--
-- Filtros para la tabla `forma_venta`
--
ALTER TABLE `forma_venta`
  ADD CONSTRAINT `fk_forma_pago` FOREIGN KEY (`codigo_forma_pago`) REFERENCES `forma_pago` (`codigo_forma_pago`),
  ADD CONSTRAINT `fk_forma_venta` FOREIGN KEY (`codigo_venta`) REFERENCES `venta` (`codigo_venta`);

--
-- Filtros para la tabla `productos`
--
ALTER TABLE `productos`
  ADD CONSTRAINT `fk_producto_categoria` FOREIGN KEY (`categoria`) REFERENCES `categoria` (`codigo_categoria`);

--
-- Filtros para la tabla `proveedor_producto`
--
ALTER TABLE `proveedor_producto`
  ADD CONSTRAINT `fk_provprod_producto` FOREIGN KEY (`producto`) REFERENCES `productos` (`codigo_productos`),
  ADD CONSTRAINT `fk_provprod_proveedor` FOREIGN KEY (`proveedor`) REFERENCES `proveedores` (`rif_proveedor`),
  ADD CONSTRAINT `fk_provprod_statud` FOREIGN KEY (`statud_proveedor`) REFERENCES `statud` (`id_statud`);

--
-- Filtros para la tabla `usuario`
--
ALTER TABLE `usuario`
  ADD CONSTRAINT `fk_usuario_empleado` FOREIGN KEY (`cedula_usuario`) REFERENCES `empleado` (`cedula_empleado`),
  ADD CONSTRAINT `fk_usuario_permiso` FOREIGN KEY (`rol`) REFERENCES `permisos` (`id_permiso`),
  ADD CONSTRAINT `fk_usuario_statud` FOREIGN KEY (`statud_usuario`) REFERENCES `statud` (`id_statud`);

--
-- Filtros para la tabla `venta`
--
ALTER TABLE `venta`
  ADD CONSTRAINT `fk_venta_cliente` FOREIGN KEY (`cliente`) REFERENCES `cliente` (`cedula_cliente`);
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
