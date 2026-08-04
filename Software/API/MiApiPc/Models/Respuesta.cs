namespace MiApiPc.Models
{
    public class Respuesta //creo una clase para darle una estructura a la respuesta que voy a enviar
    {
        public string? status { get; set; } // indica el estado de la respuesta, si fue exitosa o no
        public bool exito { get; set; } // indica True si la operación fue exitosa, False si hubo un error
        public string? message { get; set; } // mensaje de texto explicando que paso
        public dynamic? result { get; set; } //guarda los datos que devolvio SQL (si hay)

        public Respuesta()
        {
            status = "success";
        }
    }
}