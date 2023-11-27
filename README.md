# SQL_Gobierno
Estas querys ayudan a obtener algunas estadísticas de cada tabla de una base de datos.

Este script de SQL Server está destinado a recopilar información de las tablas y columnas de una base de datos en particular. Veamos paso a paso qué hace cada sección del script:

Creación de tabla temporal #ValoresUnicos:

Se crea una tabla temporal para almacenar el recuento de valores únicos por columna en cada tabla. La tabla tiene columnas para el nombre del esquema, nombre de la tabla, nombre de la columna y el recuento de valores únicos.

Recopilación de recuentos de valores únicos:

Utiliza un cursor para iterar a través de las tablas y columnas de la base de datos.
Por cada columna, genera una consulta dinámica para contar los valores únicos usando COUNT(DISTINCT).
Inserta estos recuentos en la tabla temporal #ValoresUnicos.

Creación de tabla temporal #ConteoFilas:
Se crea otra tabla temporal para almacenar la cantidad de filas por tabla en la base de datos. Esta tabla contiene columnas para el esquema, nombre de la tabla y la cantidad de filas.

Recopilación de la cantidad de filas por tabla:
Utiliza un cursor similar para iterar a través de las tablas y contar las filas en cada una.
Genera consultas dinámicas para contar las filas en cada tabla y las inserta en la tabla temporal #ConteoFilas.

Creación de tabla temporal #Examples:
Se crea una tercera tabla temporal para almacenar ejemplos de valores para cada columna en cada tabla.
Utiliza un cursor para recorrer todas las tablas y, para cada tabla, recorre sus columnas para obtener un ejemplo del valor de cada columna.

Consulta final:
Realiza una consulta que une las tablas temporales #ValoresUnicos, #ConteoFilas y #Examples.
Muestra el esquema, nombre de la tabla, nombre de la columna, recuento de valores únicos, cantidad de filas y un ejemplo del valor para cada columna.

Eliminación de tablas temporales:
Al final, las tablas temporales creadas (#ValoresUnicos, #ConteoFilas, #Examples) se eliminan.
Este script es útil para analizar las estadísticas de las columnas en las tablas de una base de datos, obteniendo el recuento de valores únicos, la cantidad de filas por tabla y ejemplos de valores en las columnas. Utiliza cursores y consultas dinámicas para lograr esta funcionalidad, aunque los cursores a veces pueden impactar en el rendimiento en bases de datos muy grandes debido a su naturaleza iterativa.
