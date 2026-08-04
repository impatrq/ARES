using System;
using System.Collections.Generic;
using MiApiPc.Datos;


namespace MiApiPc.Models
{

 public class Canal1
  {
    public int Idcanal { get; set; } //identificador del canal

    public float ValorECG{ get; set;} // señal de electrocardiograma (AD8232)

    public int Pulso {get; set;} // latidos por minuto calculados

    public DateTime Fecha {get; set;} // momento de la medicion

    public static Respuesta Agregar(Canal1 canal)
    {
      //creamos una lista donde metemos cada parametro que vamos a enviar a la base de datos
      List<Parametro> parametros = new List<Parametro>
      {
        new Parametro("@ValorECG", canal.ValorECG),
        new Parametro("@Pulso", canal.Pulso),
        new Parametro("@Fecha", DateTime.Now) // usamos la fecha y hora actual para registrar el momento de la medición 
      };
      // retornamos la respuesta de la operación
      return DBdatos.Ejecutar("sp_GuardarMedicionECG", parametros);
    }

    public static Respuesta ObtenerDatos()
    {
      //creamos una lista vacía de parámetros ya que el procedimiento almacenado no requiere ninguno
      List<Parametro> parametros = new List<Parametro>(); 
      // Ejecuta el procedimiento almacenado para obtener las mediciones de ECG
      return DBdatos.Ejecutar("sp_ObtenerMedicionesECG", parametros);
    }
  }
}