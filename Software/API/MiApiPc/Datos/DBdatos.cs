using System;
using System.Collections.Generic;
using System.Data;
using Microsoft.Data.SqlClient;
using MiApiPc.Models; // para que reconozca "Respuesta" y "Parametro"

namespace MiApiPc.Datos
{
    public class DBdatos // clase encargada de manejar la conexion a SQL y ejecutar procedimientos
    {
        // cadena de conexion fija con datos de acceso al servidor SQL
        public static string preconex = "Server=localhost\\SQLEXPRESS;Database=ARES;User Id=Angels;Password=ares2026;TrustServerCertificate=True;";

        // metodo generico para ejecutar cualquier procedimiento almacenado en SQL
        public static Respuesta Ejecutar(string nombreProcedimiento, List<Parametro> parametros, string stringConexion = "")
        {
            Respuesta respuesta = new Respuesta();
            respuesta.message = "";
            respuesta.exito = false;

        // si no le pasamos una cadena de conexion, usamos la fija (preconex), sino usamos la que nos pasaron
            string cadenaFinal = string.IsNullOrEmpty(stringConexion) ? preconex : stringConexion;

        // El 'using' asegura que la conexión se cierre y destruya al terminar, liberando memoria
            using (SqlConnection conexion = new SqlConnection(cadenaFinal))
            {
                try
                {
                    conexion.Open(); // abre la conexion a la base de datos

                // Prepara el comando con el nombre del procedimiento y la conexión abierta
                    using (SqlCommand cmd = new SqlCommand(nombreProcedimiento, conexion))
                    {
                        cmd.CommandType = CommandType.StoredProcedure; // le avisa a C# que es un procedimiento almacenado

                    // Si le mandamos parámetros, los recorre uno por uno y se los inyecta al comando
                        if (parametros != null)
                        {
                            foreach (var param in parametros)
                            {
                                // Agrego parámetros al procedimiento de SQL
                                cmd.Parameters.AddWithValue(param.Nombre, param.Valor);
                            }
                        }

                        // Ejecuta el procedimiento en SQL y lee las filas que devuelva (si devuelve algo)
                        using (SqlDataReader lector = cmd.ExecuteReader())
                        {
                            var resultados = new List<Dictionary<string, object>>();
                        
                            // Recorre fila por fila el resultado de SQL y lo transforma en un formato legible para C#
                            while (lector.Read())
                            {
                                var fila = new Dictionary<string, object>();
                                for (int i = 0; i < lector.FieldCount; i++)
                                {
                                    fila[lector.GetName(i)] = lector.GetValue(i);
                                }
                                resultados.Add(fila);
                            }
                            
                            respuesta.result = resultados; // Guarda la lista de filas adentro de la respuesta
                        }
                    // Si todo salió bien hasta acá, marca éxito
                        respuesta.exito = true;
                        respuesta.status = "success";
                        respuesta.message = "Ejecutado correctamente.";
                    }
                }
                catch (Exception ex) // Si algo falla (ej: contraseña mal, SQL apagado), cae acá
                {
                    respuesta.status = "error";
                    respuesta.exito = false;
                    respuesta.message = "Error en Base de Datos: " + ex.Message; // Te dice el error exacto
                }
            }

            return respuesta; // Devuelve el paquete final con el resultado de la operación
        }
    }
}