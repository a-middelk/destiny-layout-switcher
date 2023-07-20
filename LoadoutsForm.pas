unit LoadoutsForm;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, System.ImageList,
  Vcl.ImgList, ExtCtrls, Menus, Classes,
  KeyObserver, LoadoutsController, StateMachine;

type
  TLoadoutsFrm = class(TForm)
    trayIcon: TTrayIcon;
    popupMenu: TPopupMenu;
    miExit: TMenuItem;
    miSeparator: TMenuItem;
    stepper: TTimer;
    procedure miExitClick(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
  private
    keyObserver: TKeyObserver;
    controller: TLoadoutsController;
    machine: TStateMachine<TLoadoutState>;
    currentSet: string;

    function GetSetName(const Path: string): string;
    procedure ActivateSet(const Path: string);

    procedure miActivateSetClick(Sender: TObject);
    procedure OnRawInput(var Msg: TMessage); message WM_INPUT;
    procedure OnCompleted(ElapsedMsec: Int64);
  end;

var
  LoadoutsFrm: TLoadoutsFrm;

implementation

uses
  Types;

{$R *.dfm}

procedure TLoadoutsFrm.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  keyObserver.Deactivate;
end;

procedure TLoadoutsFrm.FormCreate(Sender: TObject);
var
  sets: TStringDynArray;
  basePath: string;
  menuItem: TMenuItem;
  i: Integer;
begin
  machine := TStateMachine<TLoadoutState>.Create(stepper, OnCompleted);
  controller := TLoadoutsController.Create(machine);
  keyObserver := TKeyObserver.Create;

  basePath := GetCurrentDir;
  if ParamCount >= 1 then
    basePath := ParamStr(1);

  sets := controller.GetLoadoutSets(basePath);
  for i := 0 to Length(sets) - 1 do
  begin
    menuItem := TMenuItem.Create(Self);
    menuItem.Name := 'miSet' + IntToStr(i);
    menuItem.Caption := GetSetName(sets[i]);
    menuItem.Hint := sets[i];
    menuItem.OnClick := miActivateSetClick;
    menuItem.RadioItem := True;
    popupMenu.Items.Insert(0, menuItem);
  end;
end;

function TLoadoutsFrm.GetSetName(const Path: string): string;
begin
  result := ChangeFileExt(ExtractFileName(Path), '');
end;

procedure TLoadoutsFrm.miActivateSetClick(Sender: TObject);
var
  path: string;
begin
  TMenuItem(Sender).Checked := True;
  path := TMenuItem(Sender).Hint;
  ActivateSet(path);
end;

procedure TLoadoutsFrm.ActivateSet(const Path: string);
resourcestring
  sTrayHint = 'Selected set: %s';
begin
  currentSet := GetSetName(Path);
  trayIcon.Hint := Format(sTrayHint, [currentSet]);

  keyObserver.Deactivate;
  controller.LoadLoadoutSet(path);
  keyObserver.Activate(Handle, controller.OnExternalKeyDown);
end;

procedure TLoadoutsFrm.FormDestroy(Sender: TObject);
begin
  keyObserver.Free;
  controller.Free;
  machine.Free;
end;

procedure TLoadoutsFrm.miExitClick(Sender: TObject);
begin
  Application.Terminate;
end;

procedure TLoadoutsFrm.OnCompleted(ElapsedMsec: Int64);
resourcestring
  sTrayHint = '%s: %d msec elapsed';
begin
  trayIcon.Hint := Format(sTrayHint, [currentSet, ElapsedMsec]);
end;

procedure TLoadoutsFrm.OnRawInput(var Msg: TMessage);
begin
  if Assigned(keyObserver) then
    keyObserver.ProcessRawInput(Msg);

  inherited;
end;

end.
