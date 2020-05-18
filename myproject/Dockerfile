FROM mcr.microsoft.com/dotnet/core/aspnet:3.1
EXPOSE 80

COPY bin/Release/netcoreapp3.1/publish/ App/
WORKDIR /App
ENTRYPOINT [ "dotnet","myproject.dll" ]