# TP easy_deploy — Dockerfile volontairement simple pour commencer.
# À améliorer pendant le TP : multi-stage build, runtime sans SDK, support multi-arch.

FROM mcr.microsoft.com/dotnet/sdk:7.0

WORKDIR /source

COPY *.csproj ./
RUN dotnet restore

COPY . .

# TODO formation : remplacer dotnet run par dotnet publish + image runtime.
CMD ["dotnet", "run"]
