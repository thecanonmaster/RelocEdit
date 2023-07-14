unit PE;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Contnrs, JwaWinNT;

type
  TBaseRelocationType = (brtAbsolute, brtHigh, brtLow, brtHighLow, brtHighAdj);
  TResult = (rOk, rRelocSectionNotFound, rVirtualSizeMoreThanRawSize);

  { TRelocItem }

  TRelocItem = class(TObject)
  public
    wOffset: Word;
    eType: TBaseRelocationType;
  end;

  { TRelocPage }

  TRelocPage = class(TObject)
  public
    dwAddress: DWord;
    dwSize: DWord;
    nCount: Integer;
    aItems: TFPObjectList;
    procedure CalcSize;
    constructor Create;
    destructor Destroy; override;
  end;

const
  ResultToStr: array[TResult] of string =
    ('OK',
     'Relocation section is not found!',
     'Virtual size is more than raw size!');
  BaseRelocationTypeStr: array[TBaseRelocationType] of string =
    ('ABSOLUTE', 'HIGH', 'LOW', 'HIGH_LOW', 'HIGH_ADJ');

var
  g_aRelocPages: TFPObjectList;
  g_strRelocSectionName: string;
  g_dwRS_RawAddress: DWord;
  g_dwRS_OrigVirtualSize: DWord;
  g_dwRS_UpdatedVirtualSize: DWord;
  g_dwRS_RawSize: DWord;

function PE_LoadFile(strFilename: string): TResult;
procedure PE_UnloadFile;
procedure PE_ReadHeaders;
function PE_ReadRelocations: TResult;
function PE_CalcVirtualSize: DWord;
function PE_SaveFile(strFilename: string): TResult;
procedure PE_WriteRelocSection(MS: TMemoryStream);
procedure PE_ExportRelocSection(strFilename: string; bFromStream: Boolean);

implementation

var
  g_MemoryStream: TMemoryStream;
  g_ImageDosHeader: TImageDosHeader;
  g_ImageNtHeaders: TImageNtHeaders32;
  g_aSectionHeaders: array of TImageSectionHeader;

function PE_LoadFile(strFilename: string): TResult;
begin
  g_MemoryStream := TMemoryStream.Create;
  g_MemoryStream.LoadFromFile(strFilename);
  PE_ReadHeaders();
  Result := PE_ReadRelocations();
end;

procedure PE_UnloadFile;
begin
  SetLength(g_aSectionHeaders, 0);
  g_MemoryStream.Free;
  g_aRelocPages.Free;
end;

procedure PE_ReadHeaders;
var dwFirstSection: DWord;
    i: Integer;
begin
  g_MemoryStream.ReadBuffer(g_ImageDosHeader, SizeOf(TImageDosHeader));
  g_MemoryStream.Seek(g_ImageDosHeader.e_lfanew, soFromBeginning);
  g_MemoryStream.ReadBuffer(g_ImageNtHeaders, SizeOf(TImageNtHeaders32));

  dwFirstSection := g_ImageDosHeader.e_lfanew +
    g_ImageNtHeaders.FileHeader.SizeOfOptionalHeader +
    sizeof(TImageFileHeader) + SizeOf(DWord);

  g_MemoryStream.Seek(dwFirstSection, soFromBeginning);

  SetLength(g_aSectionHeaders, g_ImageNtHeaders.FileHeader.NumberOfSections);
  for i := 0 to g_ImageNtHeaders.FileHeader.NumberOfSections - 1 do
  begin
    g_MemoryStream.ReadBuffer(g_aSectionHeaders[i], SizeOf(TImageSectionHeader));
  end;
end;

function PE_ReadRelocations: TResult;
var i, j: Integer;
    bRelocSectionFound: Boolean = False;
    pDirectory: PImageDataDirectory;
    i64End: Int64;
    dwAddressAndSize: array[0..1] of DWord = (0, 0);
    Page: TRelocPage;
    wData: Word = 0;
    Item: TRelocItem;
begin
  g_aRelocPages := TFPObjectList.Create(True);

  for i := 0 to g_ImageNtHeaders.FileHeader.NumberOfSections - 1 do
  begin
    pDirectory := @g_ImageNtHeaders.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_BASERELOC];
    if g_aSectionHeaders[i].VirtualAddress = pDirectory^.VirtualAddress then
    begin
      g_strRelocSectionName := PChar(@g_aSectionHeaders[i].Name);
      g_dwRS_OrigVirtualSize := pDirectory^.Size;
      g_dwRS_UpdatedVirtualSize := g_dwRS_OrigVirtualSize;
      g_dwRS_RawSize := g_aSectionHeaders[i].SizeOfRawData;
      g_dwRS_RawAddress := g_aSectionHeaders[i].PointerToRawData;
      bRelocSectionFound := True;
      Break;
    end;
  end;

  if not bRelocSectionFound then
    Exit(rRelocSectionNotFound);

  g_MemoryStream.Seek(g_dwRS_RawAddress, soFromBeginning);
  i64End := Int64(g_dwRS_RawAddress) + Int64(g_dwRS_OrigVirtualSize);

  while g_MemoryStream.Position < i64End do
  begin
    g_MemoryStream.ReadBuffer(dwAddressAndSize[0], SizeOf(DWord) << 1);

    Page := TRelocPage.Create;
    Page.dwAddress := dwAddressAndSize[0];
    Page.dwSize := dwAddressAndSize[1];
    Page.nCount := (Page.dwSize - (SizeOf(DWord) << 1)) >> 1;

    for j := 0 to Page.nCount - 1 do
    begin
      wData := g_MemoryStream.ReadWord();

      Item := TRelocItem.Create;
      Item.eType := TBaseRelocationType((wData and $F000) >> 12);
      Item.wOffset := (wData and $0FFF);

      Page.aItems.Add(Item);
    end;

    g_aRelocPages.Add(Page);
  end;
  Result := rOk;
end;

function PE_CalcVirtualSize: DWord;
var i: Integer;
    Page: TRelocPage;
    dwRemainder: DWord;
begin
  Result := 0;
  for i := 0 to g_aRelocPages.Count - 1 do
  begin
    Page := TRelocPage(g_aRelocPages.Items[i]);
    Result := Result + Page.dwSize;
  end;
  dwRemainder := Result mod SizeOf(DWord);
  if dwRemainder > 0 then
    Result := Result + dwRemainder;
end;

function PE_SaveFile(strFilename: string): TResult;
var pImageNtHeaders: PImageNtHeaders32;
begin
  if g_dwRS_UpdatedVirtualSize > g_dwRS_RawAddress then
    Exit(rVirtualSizeMoreThanRawSize);

  pImageNtHeaders := g_MemoryStream.Memory + g_ImageDosHeader.e_lfanew;
  pImageNtHeaders^.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_BASERELOC].Size :=
    g_dwRS_UpdatedVirtualSize;

  g_MemoryStream.Seek(g_dwRS_RawAddress, soFromBeginning);
  PE_WriteRelocSection(g_MemoryStream);
  g_MemoryStream.SaveToFile(strFilename);
  Result := rOk;
end;

procedure PE_WriteRelocSection(MS: TMemoryStream);
var i, j: Integer;
    Page: TRelocPage;
    Item: TRelocItem;
    wData: Word;
begin
  FillByte((MS.Memory + MS.Position)^, g_dwRS_RawSize, 0);
  for i := 0 to g_aRelocPages.Count - 1 do
  begin
    Page := TRelocPage(g_aRelocPages.Items[i]);
    MS.WriteDWord(Page.dwAddress);
    MS.WriteDWord(Page.dwSize);
    for j := 0 to Page.nCount - 1 do
    begin
      Item := TRelocItem(Page.aItems[j]);
      wData := Word(Item.eType) << 12 + Item.wOffset;
      MS.WriteWord(wData);
    end;
  end;
end;

procedure PE_ExportRelocSection(strFilename: string; bFromStream: Boolean);
var FS: TFileStream;
    MS: TMemoryStream;
begin
  if not bFromStream then
  begin
    MS := TMemoryStream.Create;
    MS.SetSize(g_dwRS_RawSize);
    PE_WriteRelocSection(MS);
    MS.SaveToFile(strFilename);
    MS.Free;
  end
  else
  begin
    FS := TFileStream.Create(strFilename, fmCreate + fmOpenWrite);
    FS.WriteBuffer((g_MemoryStream.Memory + g_dwRS_RawAddress)^, g_dwRS_RawSize);
    FS.Free;
  end;
end;

{ TRelocPage }

procedure TRelocPage.CalcSize;
begin
  dwSize := nCount << 1 + (SizeOf(DWord) << 1);
end;

constructor TRelocPage.Create;
begin
  aItems := TFPObjectList.Create(True);
  nCount := 0;
end;

destructor TRelocPage.Destroy;
begin
  aItems.Free;
  inherited Destroy;
end;

end.

