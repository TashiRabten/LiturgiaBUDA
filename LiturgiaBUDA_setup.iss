[Setup]
AppName=LiturgiaBUDA
AppVersion=1.0.1
AppPublisher=Tashi
DefaultDirName={autopf}\LiturgiaBUDA
DefaultGroupName=LiturgiaBUDA
OutputDir=installer
OutputBaseFilename=LiturgiaBUDA_setup
Compression=lzma
SolidCompression=yes
WizardStyle=modern
ArchitecturesInstallIn64BitMode=x64
ArchitecturesAllowed=x64
SetupIconFile=windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\liturgiabuda.exe

[Languages]
Name: "brazilianportuguese"; MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"

[Tasks]
Name: "desktopicon"; Description: "Criar atalho na Área de Trabalho"; GroupDescription: "Atalhos:"; Flags: unchecked

[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\LiturgiaBUDA"; Filename: "{app}\liturgiabuda.exe"
Name: "{group}\Desinstalar LiturgiaBUDA"; Filename: "{uninstallexe}"
Name: "{userdesktop}\LiturgiaBUDA"; Filename: "{app}\liturgiabuda.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\liturgiabuda.exe"; Description: "Abrir LiturgiaBUDA"; Flags: nowait postinstall skipifsilent
