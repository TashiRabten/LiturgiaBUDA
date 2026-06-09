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
; Auto-exclusão do instalador: um cmd oculto e destacado tenta excluir {srcexe}
; a cada ~2 s por até ~3 min. Enquanto o setup ainda roda, o arquivo está
; bloqueado e o del falha; assim que o assistente fecha, a exclusão ocorre.
; Se o usuário cancelar ou demorar além do limite, o instalador apenas
; permanece em Downloads (comportamento antigo) — nunca é um erro.
; Protegido por ShouldSelfDelete: só dispara quando o setup roda de uma pasta
; Downloads, preservando artefatos de build locais e cópias arquivadas.
Filename: "{cmd}"; Parameters: "/c for /l %i in (1,1,90) do (ping -n 3 127.0.0.1 >nul & del ""{srcexe}"" >nul 2>&1 & if not exist ""{srcexe}"" exit)"; Check: ShouldSelfDelete; Flags: runhidden nowait

[Code]
// Só auto-excluir quando o setup foi executado de uma pasta Downloads (caminho
// padrão de download manual e de atualizações). Builds locais ficam intactos.
function ShouldSelfDelete(): Boolean;
begin
  Result := Pos('\downloads\', Lowercase(ExpandConstant('{srcexe}'))) > 0;
end;
