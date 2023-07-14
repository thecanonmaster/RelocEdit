unit Main;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ComCtrls, Menus,
  StdCtrls, StrUtils, LCLType, PE;

const
  C_ERROR = 'Error';
  C_SUCCESS = 'Success';
  C_CONFIRMATION = 'Confirmation';
  C_APP_VERSION = '0.01';
  C_SEPARATOR = '----------------';
  C_BASE_ADDR = $10000000;

type

  { TfrmMain }

  TfrmMain = class(TForm)
    btnAddItemAfter: TButton;
    btnMovePageDown: TButton;
    btnAddPageAfter: TButton;
    btnAddPageBefore: TButton;
    btnMoveItemUp: TButton;
    btnMoveItemDown: TButton;
    btnMovePageUp: TButton;
    btnDeletePage: TButton;
    btnSetTypeAndOffset: TButton;
    btnAddItemBefore: TButton;
    btnDeleteItem: TButton;
    cbxType: TComboBox;
    edtItemOffset: TEdit;
    edtPageOffset: TEdit;
    gbxEditor: TGroupBox;
    ilMain: TImageList;
    Label1: TLabel;
    lblItemOffset: TLabel;
    lblPageOffset: TLabel;
    lvItems: TListView;
    lvPages: TListView;
    mmiExportUpdSection: TMenuItem;
    mmiExportOrigSection: TMenuItem;
    mmiTools: TMenuItem;
    mmoInfo: TMemo;
    mmiClose: TMenuItem;
    mmiQuit: TMenuItem;
    mmiSeparator1: TMenuItem;
    mmiSave: TMenuItem;
    mmiOpen: TMenuItem;
    mmiFile: TMenuItem;
    mmiAbout: TMenuItem;
    mmiHelp: TMenuItem;
    mmMenu: TMainMenu;
    odMain: TOpenDialog;
    sdMain: TSaveDialog;
    sbMain: TStatusBar;
    procedure btnAddItemClick(Sender: TObject);
    procedure btnAddPageClick(Sender: TObject);
    procedure btnDeleteItemClick(Sender: TObject);
    procedure btnDeletePageClick(Sender: TObject);
    procedure btnMoveItemClick(Sender: TObject);
    procedure btnMovePageClick(Sender: TObject);
    procedure btnSetTypeAndOffsetClick(Sender: TObject);
    procedure FormClose(Sender: TObject; var {%H-}CloseAction: TCloseAction);
    procedure FormCreate(Sender: TObject);
    procedure lvItemsDblClick(Sender: TObject);
    procedure lvItemsSelectItem(Sender: TObject; {%H-}SelectedItem: TListItem;
      {%H-}Selected: Boolean);
    procedure lvPagesDblClick(Sender: TObject);
    procedure lvPagesSelectItem(Sender: TObject; SelectedItem: TListItem;
      Selected: Boolean);
    procedure mmiAboutClick(Sender: TObject);
    procedure mmiCloseClick(Sender: TObject);
    procedure mmiExportOrigSectionClick(Sender: TObject);
    procedure mmiExportUpdSectionClick(Sender: TObject);
    procedure mmiOpenClick(Sender: TObject);
    procedure mmiQuitClick(Sender: TObject);
    procedure mmiSaveClick(Sender: TObject);
  private
    procedure Unload;
    procedure UpdatePages;
    procedure UpdateInfo;
    procedure UpdateEditor;
    function CreateRelocPage(strOffset: string; var Page: TRelocPage): string;
    function CreateRelocItem(nType: Integer; strOffset: string;
      var Item: TRelocItem): string;
  public

  end;

var
  frmMain: TfrmMain;
  g_bFileLoaded: Boolean = False;

implementation

{$R *.lfm}

{ TfrmMain }

procedure TfrmMain.mmiAboutClick(Sender: TObject);
begin
  Application.MessageBox('RelocEdit v' + C_APP_VERSION, 'About',
    MB_ICONASTERISK);
end;

procedure TfrmMain.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  Unload;
end;

procedure TfrmMain.btnSetTypeAndOffsetClick(Sender: TObject);
var Page: TRelocPage;
    Item: TRelocItem;
    NewItem: TRelocItem = nil;
    strMsg: string;
begin
  strMsg := CreateRelocItem(cbxType.ItemIndex, edtItemOffset.Text, NewItem);
  if strMsg = '' then
  begin
    Page := TRelocPage(lvPages.Selected.SubItems.Objects[0]);
    Item := TRelocItem(lvItems.Selected.SubItems.Objects[0]);
    Item.eType := NewItem.eType;
    Item.wOffset := NewItem.wOffset;
    lvItems.Selected.SubItems[0] :=
      (C_BASE_ADDR + Page.dwAddress + Item.wOffset).ToHexString(8);
    lvItems.Selected.Caption := BaseRelocationTypeStr[Item.eType];
    lvItems.Selected.SubItems[1] := Item.wOffset.ToHexString(4);
    NewItem.Free;
  end
  else
  begin
    Application.MessageBox(PChar(strMsg), C_ERROR, MB_ICONEXCLAMATION);
  end;
end;

procedure TfrmMain.btnAddItemClick(Sender: TObject);
var NewItem: TRelocItem = nil;
    Page: TRelocPage;
    strMsg: string;
    nInsertIndex: Integer = 0;
    bAfter: Boolean;
begin
  strMsg := CreateRelocItem(cbxType.ItemIndex, edtItemOffset.Text, NewItem);
  if strMsg = '' then
  begin
    Page := TRelocPage(lvPages.Selected.SubItems.Objects[0]);
    bAfter := (Sender as TControl).Name.Contains('After');

    if lvItems.Selected = nil then
    begin
      if bAfter then nInsertIndex := Page.aItems.Count;
      Page.aItems.Insert(nInsertIndex, NewItem)
    end
    else
    begin
      nInsertIndex := Integer(lvItems.Selected.SubItems.Objects[1]);
      if bAfter then Inc(nInsertIndex, 1);
      Page.aItems.Insert(nInsertIndex, NewItem);
    end;

    Page.nCount := Page.nCount + 1;
    g_dwRS_UpdatedVirtualSize := PE_CalcVirtualSize;
    lvPagesSelectItem(Sender, lvPages.Selected, True);
  end
  else
  begin
    Application.MessageBox(PChar(strMsg), C_ERROR, MB_ICONEXCLAMATION);
  end;
end;

procedure TfrmMain.btnAddPageClick(Sender: TObject);
var NewPage: TRelocPage = nil;
    strMsg: string;
    nInsertIndex: Integer = 0;
    bAfter: Boolean;
begin
   strMsg := CreateRelocPage(edtPageOffset.Text, NewPage);
   if strMsg = '' then
   begin
     bAfter := (Sender as TControl).Name.Contains('After');

     if lvPages.Selected = nil then
     begin
       if bAfter then nInsertIndex := g_aRelocPages.Count;
       g_aRelocPages.Insert(nInsertIndex, NewPage)
     end
     else
     begin
       nInsertIndex := Integer(lvPages.Selected.SubItems.Objects[1]);
       if bAfter then Inc(nInsertIndex, 1);
       g_aRelocPages.Insert(nInsertIndex, NewPage);
     end;
     g_dwRS_UpdatedVirtualSize := PE_CalcVirtualSize;
     UpdatePages;
   end
   else
   begin
     Application.MessageBox(PChar(strMsg), C_ERROR, MB_ICONEXCLAMATION);
   end;
end;

procedure TfrmMain.btnDeleteItemClick(Sender: TObject);
var Page: TRelocPage;
begin
  if Application.MessageBox('Do you want to delete selected item?',
    C_CONFIRMATION, MB_YESNO) = IDYES then
  begin
    Page := TRelocPage(lvPages.Selected.SubItems.Objects[0]);
    Page.aItems.Delete(Integer(lvItems.Selected.SubItems.Objects[1]));
    Page.nCount := Page.nCount - 1;
    g_dwRS_UpdatedVirtualSize := PE_CalcVirtualSize;
    lvPagesSelectItem(Sender, lvPages.Selected, True);
  end;
end;

procedure TfrmMain.btnDeletePageClick(Sender: TObject);
begin
  if Application.MessageBox('Do you want to delete selected page?',
    C_CONFIRMATION, MB_YESNO) = IDYES then
  begin
    g_aRelocPages.Delete(Integer(lvPages.Selected.SubItems.Objects[1]));
    g_dwRS_UpdatedVirtualSize := PE_CalcVirtualSize;
    UpdatePages;
  end;
end;

procedure TfrmMain.btnMoveItemClick(Sender: TObject);
var Page: TRelocPage;
    bUp: Boolean;
    nSelectedIndex: Integer;
begin
  Page := TRelocPage(lvPages.Selected.SubItems.Objects[0]);
  bUp := (Sender as TControl).Name.Contains('Up');
  nSelectedIndex := Integer(lvItems.Selected.SubItems.Objects[1]);
  if bUp then
  begin
    if nSelectedIndex = 0 then
    begin
      Application.MessageBox('Can''t move the item up!', C_ERROR,
        MB_ICONEXCLAMATION);
      Exit;
    end;
    Page.aItems.Exchange(nSelectedIndex, nSelectedIndex - 1);
  end
  else
  begin
    if nSelectedIndex = Page.aItems.Count - 1 then
    begin
      Application.MessageBox('Can''t move the item down!', C_ERROR,
        MB_ICONEXCLAMATION);
      Exit;
    end;
    Page.aItems.Exchange(nSelectedIndex, nSelectedIndex + 1);
  end;
  lvPagesSelectItem(Sender, lvPages.Selected, True);
end;

procedure TfrmMain.btnMovePageClick(Sender: TObject);
var bUp: Boolean;
    nSelectedIndex: Integer;
begin
  bUp := (Sender as TControl).Name.Contains('Up');
  nSelectedIndex := Integer(lvPages.Selected.SubItems.Objects[1]);
  if bUp then
  begin
    if nSelectedIndex = 0 then
    begin
      Application.MessageBox('Can''t move the item up!', C_ERROR,
        MB_ICONEXCLAMATION);
      Exit;
    end;
    g_aRelocPages.Exchange(nSelectedIndex, nSelectedIndex - 1);
  end
  else
  begin
    if nSelectedIndex = g_aRelocPages.Count - 1 then
    begin
      Application.MessageBox('Can''t move the item down!', C_ERROR,
        MB_ICONEXCLAMATION);
      Exit;
    end;
    g_aRelocPages.Exchange(nSelectedIndex, nSelectedIndex + 1);
  end;
  UpdatePages;
end;

procedure TfrmMain.FormCreate(Sender: TObject);
var e: TBaseRelocationType;
begin
  for e in TBaseRelocationType do
  begin
    cbxType.Items.Add(BaseRelocationTypeStr[e]);
  end;
  cbxType.ItemIndex := 0;
end;

procedure TfrmMain.lvItemsDblClick(Sender: TObject);
var Item: TRelocItem;
begin
  if lvItems.Selected <> nil then
  begin
    Item := TRelocItem(lvItems.Selected.SubItems.Objects[0]);
    cbxType.ItemIndex := Integer(Item.eType);
    edtItemOffset.Text := Item.wOffset.ToHexString(4);
  end;
end;

procedure TfrmMain.lvItemsSelectItem(Sender: TObject; SelectedItem: TListItem;
  Selected: Boolean);
begin
  UpdateEditor;
end;

procedure TfrmMain.lvPagesDblClick(Sender: TObject);
var Page: TRelocPage;
begin
  if lvPages.Selected <> nil then
  begin
    Page := TRelocPage(lvPages.Selected.SubItems.Objects[0]);
    edtPageOffset.Text := Page.dwAddress.ToHexString(8);
  end;
end;

procedure TfrmMain.lvPagesSelectItem(Sender: TObject; SelectedItem: TListItem;
  Selected: Boolean);
var i: Integer;
    Page: TRelocPage;
    Item: TRelocItem;
    ListItem: TListItem;
begin
  lvItems.BeginUpdate;
  lvItems.Clear;
  if Selected then
  begin
    Page := TRelocPage(SelectedItem.SubItems.Objects[0]);
    Page.CalcSize;
    SelectedItem.SubItems[0] := Page.nCount.ToString;
    for i := 0 to Page.aItems.Count - 1 do
    begin
      Item := TRelocItem(Page.aItems[i]);
      ListItem := lvItems.Items.Add;
      ListItem.ImageIndex := 0;
      ListItem.Caption := BaseRelocationTypeStr[Item.eType];
      ListItem.SubItems.AddObject(
        (C_BASE_ADDR + Page.dwAddress + Item.wOffset).ToHexString(8), Item);
      ListItem.SubItems.AddObject(Item.wOffset.ToHexString(4), TObject(i));
    end;
  end;
  lvItems.EndUpdate;
  UpdateInfo;
  UpdateEditor;
end;

procedure TfrmMain.mmiCloseClick(Sender: TObject);
begin
  Unload;
end;

procedure TfrmMain.mmiExportOrigSectionClick(Sender: TObject);
begin
  if g_bFileLoaded then
  begin
    sdMain.FilterIndex := 2;
    if sdMain.Execute then
    begin
      PE_ExportRelocSection(sdMain.FileName, True);
      Application.MessageBox('Original relocation section is exported!',
        C_SUCCESS, MB_ICONASTERISK);
    end;
  end;
end;

procedure TfrmMain.mmiExportUpdSectionClick(Sender: TObject);
begin
  if g_bFileLoaded then
  begin
    sdMain.FilterIndex := 2;
    if sdMain.Execute then
    begin
      PE_ExportRelocSection(sdMain.FileName, False);
      Application.MessageBox('Updated relocation section is exported!',
        C_SUCCESS, MB_ICONASTERISK);
    end;
  end;
end;

procedure TfrmMain.mmiOpenClick(Sender: TObject);
var eLoadResult: TResult;
begin
  Unload;
  if odMain.Execute then
  begin
    eLoadResult := PE_LoadFile(odMain.FileName);
    if eLoadResult <> rOK then
    begin
      Application.MessageBox(PChar(ResultToStr[eLoadResult]), C_ERROR, MB_ICONERROR);
      PE_UnloadFile();
      Exit;
    end;
    g_bFileLoaded := True;
    sbMain.SimpleText := odMain.FileName + ' [' + g_strRelocSectionName + ' ]';
    UpdatePages;
    UpdateInfo;
    UpdateEditor;
  end;
end;

procedure TfrmMain.mmiQuitClick(Sender: TObject);
begin
  Close;
end;

procedure TfrmMain.mmiSaveClick(Sender: TObject);
var eSaveResult: TResult;
begin
  if g_bFileLoaded and sdMain.Execute then
  begin
    eSaveResult := PE_SaveFile(sdMain.FileName);
    if eSaveResult = rOK then
      Application.MessageBox('File saved!', C_CONFIRMATION, MB_ICONASTERISK)
    else
      Application.MessageBox(PChar(ResultToStr[eSaveResult]), C_ERROR, MB_ICONERROR);
  end;
end;

procedure TfrmMain.Unload;
begin
  if g_bFileLoaded then
    PE_UnloadFile();
  g_bFileLoaded := False;
  sbMain.SimpleText := '';
  lvItems.BeginUpdate;
  lvItems.Clear;
  lvItems.EndUpdate;
  lvPages.BeginUpdate;
  lvPages.Clear;
  lvPages.EndUpdate;
  mmoInfo.Clear;
end;

procedure TfrmMain.UpdatePages;
var i: Integer;
    Page: TRelocPage;
    ListItem: TListItem;
begin
  if g_bFileLoaded then
  begin
    lvPages.BeginUpdate;
    lvPages.Clear;
    for i := 0 to g_aRelocPages.Count - 1 do
    begin
      Page := TRelocPage(g_aRelocPages.Items[i]);
      ListItem := lvPages.Items.Add;
      ListItem.ImageIndex := 0;
      ListItem.Caption := (C_BASE_ADDR + Page.dwAddress).ToHexString(8);
      ListItem.SubItems.AddObject(Page.nCount.ToString, Page);
      ListItem.SubItems.AddObject('', TObject(i));
    end;
    lvPages.EndUpdate;
  end;
end;

procedure TfrmMain.UpdateInfo;
var Page: TRelocPage;
begin
  mmoInfo.Clear;
  if g_bFileLoaded then
  begin
    mmoInfo.Lines.Add('Raw address: ' + g_dwRS_RawAddress.ToHexString(8));
    mmoInfo.Lines.Add('Raw size: ' + g_dwRS_RawSize.ToHexString(8));
    mmoInfo.Lines.Add('Original virtual size: ' + g_dwRS_OrigVirtualSize.ToHexString(8));
    mmoInfo.Lines.Add('Updated virtual size: ' + g_dwRS_UpdatedVirtualSize.ToHexString(8));
    mmoInfo.Lines.Add('Page count: ' + g_aRelocPages.Count.ToString);

    if lvPages.Selected <> nil then
    begin
      mmoInfo.Lines.Add('');
      Page := TRelocPage(lvPages.Selected.SubItems.Objects[0]);
      mmoInfo.Lines.Add('Page #' +
        Integer(lvPages.Selected.SubItems.Objects[1]).ToString);
      mmoInfo.Lines.Add('Address: ' + Page.dwAddress.ToHexString(8));
      mmoInfo.Lines.Add('Size: ' + Page.dwSize.ToHexString(8));
    end;
  end;
end;

procedure TfrmMain.UpdateEditor;
begin
  if (g_bFileLoaded) and (lvPages.Selected <> nil) then
  begin
    if lvItems.Selected <> nil then
    begin
      btnSetTypeAndOffset.Enabled := True;
      btnMoveItemUp.Enabled := True;
      btnMoveItemDown.Enabled := True;
      btnDeleteItem.Enabled := True;
    end
    else
    begin
      btnSetTypeAndOffset.Enabled := False;
      btnMoveItemUp.Enabled := False;
      btnMoveItemDown.Enabled := False;
      btnDeleteItem.Enabled := False;
    end;
    btnAddItemBefore.Enabled := True;
    btnAddItemAfter.Enabled := True;
    btnMovePageUp.Enabled := True;
    btnMovePageDown.Enabled := True;
    btnAddPageBefore.Enabled := True;
    btnAddPageAfter.Enabled := True;
    btnDeletePage.Enabled := True;
  end
  else
  begin
    btnSetTypeAndOffset.Enabled := False;
    btnAddItemBefore.Enabled := False;
    btnAddItemAfter.Enabled := False;
    btnMoveItemUp.Enabled := False;
    btnMoveItemDown.Enabled := False;
    btnDeleteItem.Enabled := False;
    btnMovePageUp.Enabled := False;
    btnMovePageDown.Enabled := False;
    btnAddPageBefore.Enabled := False;
    btnAddPageAfter.Enabled := False;
    btnDeletePage.Enabled := False;
  end;
end;

function TfrmMain.CreateRelocPage(strOffset: string; var Page: TRelocPage): string;
var dwAddress: DWord;
begin
  Result := '';
  if Length(strOffset) = 8 then
  begin
    try
      dwAddress := Hex2Dec(strOffset);
      Page := TRelocPage.Create;
      Page.dwAddress := dwAddress;
      Page.CalcSize;
    except
    on EConvertError do
      Result := 'Coldn''t convert address string to dword value!';
    end;
  end
  else
  begin
    Result := 'Address length should be exactly 8 hex digits!';
  end;
end;

function TfrmMain.CreateRelocItem(nType: Integer; strOffset: string;
  var Item: TRelocItem): string;
var wOffset: Word;
    eType: TBaseRelocationType;
begin
  Result := '';
  if Length(edtItemOffset.Text) = 4 then
  begin
    try
      eType := TBaseRelocationType(nType);
      wOffset := Hex2Dec(strOffset);
      Item := TRelocItem.Create;
      Item.eType := eType;
      Item.wOffset := wOffset;
    except
    on EConvertError do
      Result := 'Coldn''t convert offset string to word value!';
    end;
  end
  else
  begin
    Result := 'Offset length should be exactly 4 hex digits!';
  end;
end;

end.

