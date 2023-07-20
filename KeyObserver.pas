{$WARN SYMBOL_PLATFORM OFF}
unit KeyObserver;

interface

uses
  Classes, Windows, Winapi.Messages;

type
  TKeyNotify = procedure(VKey: Word) of object;

  TKeyObserver = class
  private
    isActive: Boolean;
    onKey: TKeyNotify;
  public
    destructor Destroy; override;

    procedure Activate(Target: HWND; KeyProc: TKeyNotify);
    procedure Deactivate;

    procedure ProcessRawInput(var Msg: TMessage);
  end;

implementation

uses
  SysUtils;

type
  TRAWINPUTDEVICE = record
    usUsagePage: WORD;
    usUsage: WORD;
    dwFlags: DWORD;
    hwndTarget: HWND;
  end;
  PRAWINPUTDEVICE = ^TRAWINPUTDEVICE;

  TRAWINPUTHEADER = record
    dwType: DWORD;
    dwSize: DWORD;
    hDevice: THANDLE;
    wParam: WPARAM;
  end;
  PRAWINPUTHEADER = ^TRAWINPUTHEADER;

  TRAWKEYBOARD = record
    MakeCode: WORD;
    Flags: WORD;
    Reserved: WORD;
    VKey: WORD;
    Message: UINT;
    ExtraInformation: ULONG;
  end;
  PRAWKEYBOARD = ^TRAWKEYBOARD;

  TRAWKEYINPUT = record
    header: TRAWINPUTHEADER;
    keyboard: TRAWKEYBOARD;
  end;
  PRAWKEYINPUT = ^TRAWKEYINPUT;

function RegisterRawInputDevices(pRawInputDevices: PRAWINPUTDEVICE;
  uiNumDevices: UINT; cbSize: UINT): BOOL; stdcall; external user32;

function GetRawInputData(hRawInput: THandle; uiCommand: UINT; pData: Pointer;
  var pcbSize: UINT; cbSizeHeader: UINT): UINT; stdcall; external user32;

const
  HID_USAGE_PAGE_GENERIC = $00000001;
  HID_USAGE_GENERIC_KEYBOARD = $00000006;
  RIDEV_NOLEGACY = $00000030;
  RIDEV_INPUTSINK = $00000100;
  RIDEV_REMOVE = $00000001;
  RIM_INPUTSINK = 1;
  RID_INPUT = $10000003;

procedure TKeyObserver.Activate(Target: HWND; KeyProc: TKeyNotify);
var
  dev: TRAWINPUTDEVICE;
begin
  onKey := KeyProc;

  dev.usUsagePage := HID_USAGE_PAGE_GENERIC;
  dev.usUsage := HID_USAGE_GENERIC_KEYBOARD;
  dev.dwFlags := RIDEV_NOLEGACY or RIDEV_INPUTSINK;
  dev.hwndTarget := Target;

  Win32Check(RegisterRawInputDevices(@dev, 1, SizeOf(dev)));
  isActive := True;
end;

procedure TKeyObserver.Deactivate;
var
  dev: TRAWINPUTDEVICE;
begin
  if isActive then
  begin
    dev.usUsagePage := HID_USAGE_PAGE_GENERIC;
    dev.usUsage := HID_USAGE_GENERIC_KEYBOARD;
    dev.dwFlags := RIDEV_REMOVE;
    dev.hwndTarget := 0;

    Win32Check(RegisterRawInputDevices(@dev, 1, SizeOf(dev)));
    isActive := False;
  end;
end;

destructor TKeyObserver.Destroy;
begin
  Deactivate;
  inherited;
end;

procedure TKeyObserver.ProcessRawInput(var Msg: TMessage);
var
  input: TRAWKEYINPUT;
  size: Cardinal;
  isExternal: Boolean;
begin
  isExternal := (Msg.WParam and $FF) = RIM_INPUTSINK;
  if not isExternal then
    Exit;

  size := SizeOf(input);
  if GetRawInputData(Msg.LParam, RID_INPUT, @input, size, SizeOf(TRAWINPUTHEADER)) <> SizeOf(TRAWKEYINPUT) then
    Exit;

  if input.keyboard.Message = WM_KEYDOWN then
    onKey(input.keyboard.VKey);
end;

end.
