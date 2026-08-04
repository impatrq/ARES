using System.Data;

namespace MiApiPc.Models 
{
    public class Parametro // clase para empaquetar cada dato que voy a enviar a SQL
    {
        // las propiedades del parametro
        public string? Nombre { get; set; } // nombre en SQL (Id, nombre, valor, etc)
        public object? Valor { get; set; } // valor del dato 
        public SqlDbType TipoDato { get; set; } // tipo de dato en SQL (INT, VARCHAR, FLOAT, etc.)
        public ParameterDirection Direccion { get; set; } // Si el dato entra o Sale de SQL

        // constructor vacio por si se necesita llenar despues
        public Parametro()
        {
        }

        // constructor que permite crear un parametro rapido con nombre y valor
        public Parametro(string nombre, object valor)
        {
            Nombre = nombre;
            Valor = valor;
            Direccion = ParameterDirection.Input; // Por defecto asumimos que el dato es de entrada
        }
    }
}
    