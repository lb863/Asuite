{
Copyright (C) 2006-2015 Matteo Salvi

Website: http://www.salvadorsoftware.com/

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
}

unit Database.Manager;

interface

uses
  Windows, SysUtils, Forms, Dialogs, VirtualTrees, DKLang,
  Classes, mORMot, SynCommons, mORMotSQLite3, Vcl.Controls;

type
  TDBManager = class
  private
    FDBFileName : string;
    FDatabase   : TSQLRestServerDB;
    FSQLModel   : TSQLModel;

    procedure DoBackupList;
    function  GetDateTimeAsString: String;
  public
    constructor Create;
    destructor Destroy; override;

    property DBFileName: string read FDBFileName write FDBFileName;
    property Database: TSQLRestServerDB read FDatabase;

    procedure Setup(const ADBFilePath: string);

    procedure LoadData(Tree: TBaseVirtualTree);
    function  SaveData(Tree: TBaseVirtualTree; DoBackup: Boolean = True): Boolean;

    procedure DeleteItem(aID: Integer);

    procedure ClearTable(SQLRecordClass:TSQLRecordClass);

    procedure ImportData(Tree: TBaseVirtualTree); //For frmImportList
    procedure ImportOptions; //For frmImportList
  end;

implementation

uses
  Kernel.Consts, AppConfig.Main, Utility.FileFolder, Utility.Misc,
  Database.Version, Database.Options, Database.List;

constructor TDBManager.Create;
begin
  FSQLModel := TSQLModel.Create([TSQLtbl_version, TSQLtbl_list, TSQLtbl_options]);
end;

procedure TDBManager.DeleteItem(aID: Integer);
begin
  if (aID > 0) then
    FDatabase.Delete(TSQLtbl_list,aID);
end;

destructor TDBManager.Destroy;
begin
  inherited;
  FDatabase.Free;
  FSQLModel.Free;
end;

procedure TDBManager.DoBackupList;
begin
  //Backup list and old delete backup
  if (Config.Backup) then
  begin
    CopyFile(PChar(FDBFileName),
             PChar(Format(Config.Paths.SuitePathBackup + BACKUP_FILE,[GetDateTimeAsString])),false);
    DeleteOldBackups(Config.BackupNumber);
  end;
end;

function TDBManager.GetDateTimeAsString: String;
begin
  DateTimeToString(Result, 'yyyy-mm-dd-hh-mm-ss',now);
end;

procedure TDBManager.ImportData(Tree: TBaseVirtualTree);
begin
  try
    TSQLtbl_list.Load(Self, Tree, True);
  except
    on E : Exception do
      ShowMessageFmtEx(DKLangConstW('msgErrGeneric'),[E.ClassName,E.Message],True);
  end;
end;

procedure TDBManager.ImportOptions;
begin
  try
    TSQLtbl_options.Load(Self, Config);
  except
    on E : Exception do
      ShowMessageFmtEx(DKLangConstW('msgErrGeneric'),[E.ClassName, E.Message], True);
  end;
end;

procedure TDBManager.ClearTable(SQLRecordClass: TSQLRecordClass);
var
  SQLData: TSQLRecord;
begin
  SQLData := SQLRecordClass.CreateAndFillPrepare(FDatabase, '');
  try
    while SQLData.FillOne do
      FDatabase.Delete(SQLRecordClass, SQLData.ID);
  finally
    SQLData.Free;
  end;
end;

procedure TDBManager.LoadData(Tree: TBaseVirtualTree);
begin
  //List & Options
  Tree.BeginUpdate;
  try
    try
      //Load Database version
      TSQLtbl_version.Load(Self);
      //Load Options
      TSQLtbl_options.Load(Self, Config);
      //Load list
      TSQLtbl_list.Load(Self, Tree, False);
    except
      on E : Exception do
        ShowMessageFmtEx(DKLangConstW('msgErrGeneric'),[E.ClassName,E.Message],True);
    end;
  finally
    Tree.EndUpdate;
  end;
end;

function TDBManager.SaveData(Tree: TBaseVirtualTree; DoBackup: Boolean): Boolean;
begin
  //If launcher is in ReadOnlyMode, exit from this function
  if (Config.ReadOnlyMode) then
    Exit(True);

  //List & Options
  try
    //Save data and do backup
    try
      //Create and open Sqlite3Dataset
      if FDatabase.TransactionBegin(TSQLtbl_list, 1) then
      begin
        TSQLtbl_list.Save(Self, Tree);
        //If settings is changed, insert it else (if it exists) update it
        if Config.Changed then
          TSQLtbl_options.Save(Self, Config);
        //Save new version info
        TSQLtbl_version.Save(Self, Config);
        //Commit data in sqlite database
        FDatabase.Commit(1);
      end;
    except
      on E : Exception do begin
        ShowMessageFmtEx(DKLangConstW('msgErrGeneric'),[E.ClassName,E.Message],True);
        FDatabase.Rollback(1);
      end;
    end;
  finally
    Result := True;
    if Result and DoBackup then
      DoBackupList;
  end;
end;

procedure TDBManager.Setup(const ADBFilePath: string);
begin
  FDBFileName := ADBFilePath;
  //Load sqlite3 database and create missing tables
  FDatabase := TSQLRestServerDB.Create(FSQLModel, FDBFileName);
  fDatabase.CreateMissingTables(0);
end;

end.
