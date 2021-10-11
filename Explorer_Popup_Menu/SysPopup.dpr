program SysPopup;

uses
  Forms,
  uSysPopupMain in 'uSysPopupMain.pas' {frmSysPopup};

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TfrmSysPopup, frmSysPopup);
  Application.Run;
end.
