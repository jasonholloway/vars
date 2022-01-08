using System.Net.Sockets;

var listener = TcpListener.Create(7777);

while (true)
{
    var tcp = await listener.AcceptTcpClientAsync();

    _ = Task.Run(() =>
    {
        try
        {
            using var str = tcp.GetStream();
            using var writer = new StreamWriter(str);
            using var reader = new StreamReader(str);


        }
        finally
        {
            tcp.Dispose();
        }
    });
}


