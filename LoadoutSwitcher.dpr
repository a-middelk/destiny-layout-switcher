program LoadoutSwitcher;



{$R *.dres}

uses
  Vcl.Forms,
  LoadoutsForm in 'LoadoutsForm.pas' {LoadoutsFrm},
  KeyObserver in 'KeyObserver.pas',
  LoadoutsController in 'LoadoutsController.pas',
  StateMachine in 'StateMachine.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := False;
  Application.ShowMainForm := False;
  Application.Title := 'Layout Switcher';
  Application.CreateForm(TLoadoutsFrm, LoadoutsFrm);
  Application.Run;
end.
