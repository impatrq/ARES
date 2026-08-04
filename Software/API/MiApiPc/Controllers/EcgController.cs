using Microsoft.AspNetCore.Mvc; //libreria para usar el controlador de API
using MiApiPc.Models; //para usar la clase Canal1 y Respuesta

//L indico que este controlador es una API y que la ruta base es "api/canal"
namespace MiApiPc.Controllers
{
    [ApiController]
    [Route("api/canal")] //ruta base para acceder a este controlador
    public class EcgController : ControllerBase
    {
        [HttpGet] //indico que este método responde a solicitudes GET
        public dynamic Listar()
        {
            return Canal1.ObtenerDatos(); //llamo al método ObtenerDatos de la clase Canal1 para obtener los datos de la base de datos y retorno la respuesta   
        }

        [HttpPost] //indico que este método responde a solicitudes POST
        public Respuesta GuardarDatos([FromBody] Canal1 datosRecibidos) //indico que la API reciba datos en formato JSON en el cuerpo de la solicitud (FromBody)
        {
           return Canal1.Agregar(datosRecibidos); //llamo al método Agregar de la clase Canal1 para guardar los datos en la base de datos y retorno la respuesta
        }
    } 
} 