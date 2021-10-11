////////////////////////////////////////////////////////////////////////////////
//
//  ****************************************************************************
//  * Unit Name : uSysPopupMain
//  * Purpose   : ���� ����������� ���������� ������������ ���� ����������.
//  * Author    : ��������� (Rouse_) ������
//  * Version   : 1.00
//  ****************************************************************************
//

unit uSysPopupMain;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ShlObj, ActiveX;

type
  TfrmSysPopup = class(TForm)
    btShow: TButton;
    edPath: TEdit;
    Label1: TLabel;
    procedure btShowClick(Sender: TObject);
  end;

var
  frmSysPopup: TfrmSysPopup;

implementation

{$R *.dfm}

// ��� ��� ������ ������ ����, ��� �������� ��������
function MenuCallback(Wnd: HWND; Msg: UINT; WParam: WPARAM;
 LParam: LPARAM): LRESULT; stdcall;
var
  ContextMenu2: IContextMenu2;
begin
  case Msg of
    WM_CREATE:
    begin
      ContextMenu2 := IContextMenu2(PCreateStruct(lParam).lpCreateParams);
      SetWindowLong(Wnd, GWL_USERDATA, Longint(ContextMenu2));
      Result := DefWindowProc(Wnd, Msg, wParam, lParam);
    end;
    WM_INITMENUPOPUP:
    begin
      ContextMenu2 := IContextMenu2(GetWindowLong(Wnd, GWL_USERDATA));
      ContextMenu2.HandleMenuMsg(Msg, wParam, lParam);
      Result := 0;
    end;
    WM_DRAWITEM, WM_MEASUREITEM:
    begin
      ContextMenu2 := IContextMenu2(GetWindowLong(Wnd, GWL_USERDATA));
      ContextMenu2.HandleMenuMsg(Msg, wParam, lParam);
      Result := 1;
    end;
  else
    Result := DefWindowProc(Wnd, Msg, wParam, lParam);
  end;
end;

// ��� ��� �������� ������ ����, ��� �������� ��������
function CreateMenuCallbackWnd(const ContextMenu: IContextMenu2): HWND;
const
  IcmCallbackWnd = 'ICMCALLBACKWND';
var
  WndClass: TWndClass;
begin
  FillChar(WndClass, SizeOf(WndClass), #0);
  WndClass.lpszClassName := PChar(IcmCallbackWnd);
  WndClass.lpfnWndProc := @MenuCallback;
  WndClass.hInstance := HInstance;
  Windows.RegisterClass(WndClass);
  Result := CreateWindow(IcmCallbackWnd, IcmCallbackWnd, WS_POPUPWINDOW, 0,
    0, 0, 0, 0, 0, HInstance, Pointer(ContextMenu));
end;

procedure GetProperties(Path: String; MousePoint: TPoint; WC: TWinControl);
var
  CoInit, AResult: HRESULT;
  CommonDir, FileName: String;
  Desktop, ShellFolder: IShellFolder;
  pchEaten, Attr: Cardinal;
  PathPIDL: PItemIDList;
  FilePIDL: array [0..1] of PItemIDList;
  ShellContextMenu: HMenu;
  ICMenu: IContextMenu;
  ICMenu2: IContextMenu2;
  PopupMenuResult: BOOL;
  CMD: TCMInvokeCommandInfo;
  M: IMAlloc;
  ICmd: Integer;
  CallbackWindow: HWND;
begin
  // ��������� �������������
  ShellContextMenu := 0;
  Attr := 0;
  PathPIDL := nil;
  CallbackWindow := 0;
  CoInit := CoInitializeEx(nil, COINIT_MULTITHREADED);
  try
    // �������� ���� � ��� ����
    CommonDir := ExtractFilePath(Path);
    FileName := ExtractFileName(Path);
    // �������� ��������� �� ��������� �������� �����
    if SHGetDesktopFolder(Desktop) <> S_OK then
      RaiseLastOSError;
    // ���� �������� � ������
    if FileName = '' then
    begin
      // �������� ��������� �� ����� "��� ���������"
      if (SHGetSpecialFolderLocation(0, CSIDL_DRIVES, PathPIDL) <> S_OK) or
        (Desktop.BindToObject(PathPIDL,  nil,  IID_IShellFolder,
          Pointer(ShellFolder)) <> S_OK) then RaiseLastOSError;
      // �������� ��������� �� ����������
      ShellFolder.ParseDisplayName(WC.Handle, nil, StringToOleStr(CommonDir),
        pchEaten, FilePIDL[0], Attr);
      // �������� ��������� �� ����������� ���� �����
      AResult := ShellFolder.GetUIObjectOf(WC.Handle, 1, FilePIDL[0],
        IID_IContextMenu, nil, Pointer(ICMenu));
    end
    else
    begin
      // �������� ��������� �� ����� "��� ���������"
      if (Desktop.ParseDisplayName(WC.Handle, nil, StringToOleStr(CommonDir),
        pchEaten, PathPIDL, Attr) <> S_OK) or
        (Desktop.BindToObject(PathPIDL, nil, IID_IShellFolder,
          Pointer(ShellFolder)) <> S_OK) then RaiseLastOSError;
      // �������� ��������� �� ����
      ShellFolder.ParseDisplayName(WC.Handle, nil, StringToOleStr(FileName),
        pchEaten, FilePIDL[0], Attr);
      // �������� ��������� �� ����������� ���� �����
      AResult := ShellFolder.GetUIObjectOf(WC.Handle, 1, FilePIDL[0],
        IID_IContextMenu, nil, Pointer(ICMenu));
    end;

    // ���� ��������� �� ����. ���� ����, ������ ���:
    if Succeeded(AResult) then
    begin
      ICMenu2 := nil;
      // ������� ����
      ShellContextMenu := CreatePopupMenu;
      // ���������� ��� ����������
      if Succeeded(ICMenu.QueryContextMenu(ShellContextMenu, 0,
        1, $7FFF, CMF_EXPLORE)) and
        Succeeded(ICMenu.QueryInterface(IContextMenu2, ICMenu2)) then
          CallbackWindow := CreateMenuCallbackWnd(ICMenu2);
      try
        // ���������� ����
        PopupMenuResult := TrackPopupMenu(ShellContextMenu, TPM_LEFTALIGN or TPM_LEFTBUTTON
          or TPM_RIGHTBUTTON or TPM_RETURNCMD,
          MousePoint.X, MousePoint.Y, 0, CallbackWindow, nil);
      finally
        ICMenu2 := nil;
      end;
      // ���� ��� ������ ����� ���� ����� ����:
      if PopupMenuResult then
      begin
        // ������ ����� ������ ����� ������ � ICmd
        ICmd := LongInt(PopupMenuResult) - 1;
        // ��������� ��������� TCMInvokeCommandInfo
        FillChar(CMD, SizeOf(CMD), #0);
        with CMD do
        begin
          cbSize := SizeOf(CMD);
          hWND := WC.Handle;
          lpVerb := MakeIntResource(ICmd);
          nShow := SW_SHOWNORMAL;
        end;
        // ��������� InvokeCommand � ����������� ����������
        AResult := ICMenu.InvokeCommand(CMD);
        if AResult <> S_OK then RaiseLastOSError;
       end;
    end;
  finally
    // ����������� ������� ������� ����� ������ ������ ������
    if FilePIDL[0] <> nil then
    begin
      // ��� ������������ ��������� IMalloc
      SHGetMAlloc(M);
      if M <> nil then
        M.Free(FilePIDL[0]);
      M:=nil;
    end;
    if PathPIDL <> nil then
    begin
      SHGetMAlloc(M);
      if M <> nil then
        M.Free(PathPIDL);
      M:=nil;
    end;
    if ShellContextMenu <>0 then
      DestroyMenu(ShellContextMenu);
    if CallbackWindow <> 0 then
      DestroyWindow(CallbackWindow);
    ICMenu := nil;
    ShellFolder := nil;
    Desktop := nil;
    if CoInit = S_OK then CoUninitialize;
  end;
end;


procedure TfrmSysPopup.btShowClick(Sender: TObject);
var
  pt: TPoint;
begin
  pt := ClientToScreen(point(btShow.Left, btShow.Top + btShow.Height));
  GetProperties(edPath.Text, pt, Self);
end;

end.
