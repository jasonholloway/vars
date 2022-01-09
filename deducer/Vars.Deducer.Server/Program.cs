using System.Diagnostics;
using System.Net.Sockets;

var listener = TcpListener.Create(7777);
Process.GetCurrentProcess().Exited += (_, _) => listener.Stop();
listener.Start();

while (true)
{
    var tcp = await listener.AcceptTcpClientAsync();

    _ = Task.Run(() =>
    {
        try
        {
            using var str = tcp.GetStream();
            using var reader = new StreamReader(str);
            using var writer = new StreamWriter(str) { AutoFlush = true };
            Hub.Run(reader, writer);
        }
        finally
        {
            tcp.Dispose();
        }
    });
}


