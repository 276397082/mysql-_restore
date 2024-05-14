        # ���������ַ���
        $username = "root"
        $password = "123456"
        $database = "test"
        $server = "127.0.0.1"




# ��������ĳ���
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

    # MySQL��������
    # ���� .NET Framework �е����
    # ȷ��MySQL Connector/NET�Ѿ���װ
    # ������ֶ����ص�DLL������ָ��·�����أ�����:
    $mysqlAssemblyPath = "MySql.Data.dll"
    [System.Reflection.Assembly]::LoadFrom($mysqlAssemblyPath) | Out-Null

# �����ļ�ѡ�񴰿����û�ѡ��ȫ��sql�ļ�
$fileDialog = New-Object System.Windows.Forms.OpenFileDialog
$fileDialog.InitialDirectory = [Environment]::GetFolderPath('Desktop')
$fileDialog.Filter = "SQL files (*.sql)|*.sql"
$fileDialog.Multiselect = $false

if ($fileDialog.ShowDialog() -eq 'OK') {
    $sqlScriptPath = $fileDialog.FileName
    $sqlPath=$fileDialog.InitialDirectory
    # ��ȡbackfull.sql�ļ�
    $sqlScript = Get-Content -Path $sqlScriptPath -Raw  -Encoding UTF8
}
else {
    Write-Host "�û�ȡ����ѡ��"
    exit
}


##�����б�
function tables_list($sqlf,$tableName){
    
    # ʹ��������ʽ��ȡ���б���
    $tablePattern = 'CREATE TABLE `(\w+)`'
    $tableMatches = [regex]::Matches($sqlf, $tablePattern)
    if ($tableName){
        $tableMatches=$tableName
    }
    # �г��������ı������û���ѡ��Ҫ��ȡ�ı�
    $checkedTables = @()
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "ѡ��Ҫ��ȡ�ı�"
    $form.Size = New-Object System.Drawing.Size(300,800)
    $form.StartPosition = "CenterScreen"
    $checkedListBox = New-Object System.Windows.Forms.CheckedListBox
    $checkedListBox.Location = New-Object System.Drawing.Point(10,10)
    $checkedListBox.Size = New-Object System.Drawing.Size(260,700)
    

    # ��� SelectedIndexChanged �¼��������
    $checkedListBox.add_SelectedIndexChanged({
        param($sender, $e)
        $selectedIndex = $checkedListBox.SelectedIndex
        if ($selectedIndex -ne -1) {
            # �л�ѡ��״̬
            $checkedListBox.SetItemChecked($selectedIndex, -not $checkedListBox.GetItemChecked($selectedIndex))
            $checkedListBox.ClearSelected() # ���ѡ��״̬����ֹ�ظ������¼�
        }
        # ����Ƿ�������һ����ѡ�У������������ȷ����ť���������
        if ($checkedListBox.CheckedItems.Count -gt 0) {
            $okButton.Enabled = $true
        } else {
            $okButton.Enabled = $false
        }
    })

    # ����Ƿ�ƥ�䵽�˱����û�У�������ʾ���˳�
    #if ($tableMatches.Count -eq 0) {
    #    Write-Host "δ�ҵ��κα��塣��ȷ�� SQL �ļ�������Ч�� CREATE TABLE ��䡣"
    #    exit
    #}
    foreach ($match in $tableMatches) {
        if ($match.Groups.Count -gt 0) {
            $tableName = $match.Groups[1].Value
        }else{
             $tableName =$match
        }
        
        $checkedListBox.Items.Add($tableName) | Out-Null
    }


    $form.Controls.Add($checkedListBox)
    $okButton = New-Object System.Windows.Forms.Button
    $okButton.Location = New-Object System.Drawing.Point(75,720)
    $okButton.Size = New-Object System.Drawing.Size(75,23)
    $okButton.Text = "ȷ��"
    $okButton.Enabled = $false # ��ʼ״̬�½���ȷ����ť
    $okButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.AcceptButton = $okButton
    $form.Controls.Add($okButton)
    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Location = New-Object System.Drawing.Point(160,720)
    $cancelButton.Size = New-Object System.Drawing.Size(75,23)
    $cancelButton.Text = "ȡ��"
    $cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $form.CancelButton = $cancelButton
    $form.Controls.Add($cancelButton)
    $form.TopMost = $true

        #$form.Add_Shown({
        ## �ڴ�����ʾʱ����Ƿ�������һ����ѡ��
        #    if ($checkedListBox.CheckedItems.Count -eq 0) {
        #        [System.Windows.Forms.MessageBox]::Show("������ѡ��һ�����", "����", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        #    }
        #})

    $result = $form.ShowDialog()
    # �����ֵ�洢��������
    $values = @($result,$checkedListBox)
    RETURN  $values

} 



    ##��ȡ�����ݼ��ṹ
    $tals=tables_list $sqlScript
    
    if ($tals[0] -ne [System.Windows.Forms.DialogResult]::OK ) {
         Write-Host "�û�ȡ���˲���1��"
        exit
    }
    #if ($tals[1].CheckedItems.Count -cle 0){
    #    [System.Windows.Forms.MessageBox]::Show("������ѡ��һ�����", "����", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
    #
    #}





 ## ���ɱ����ݼ����sql�ļ�
function GetDatatable($sqlf,$tables){

$savePaht=$sqlPath  +"\Mysql_file\"


# ����ļ����Ƿ����
if (Test-Path $savePaht -PathType Container) {
    # ����ļ��д��ڣ�������ļ����ڵ�����
    Remove-Item -Path "$savePaht\*" -Force -Recurse
    Write-Host "�ļ�������գ�$savePaht"
} else {
    # �����ļ���
    New-Item -Path $savePaht -ItemType Directory -Force | Out-Null
    Write-Host "�ļ����Ѵ�����$savePaht"
}




 # ��ÿ��ѡ�еı�ִ�л�ԭ
        foreach ($tableName in $tables) {
            $a=$savePaht + "$tableName.sql"
            # $tableSqlPattern = "CREATE TABLE ``$tableName`` \((.*?)\);"
            $tableSqlPattern = "DROP TABLE IF EXISTS ``$tableName``;(.*?)TABLES;"
            $tableSqlMatch = [regex]::Match($sqlf, $tableSqlPattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)
            if ($tableSqlMatch.Success) {
                $tableSql = $tableSqlMatch.Value

                # ����Ľṹ�����ݱ��浽�������ļ�
                $tableSql | Out-File -FilePath "$a"
            }
        }

}

 ## ���ɱ����ݼ����sql�ļ�
GetDatatable $sqlScript $tals[1].CheckedItems

##��ԭ�б�ѡ��
$talsb=tables_list $sqlScript $tals[1].CheckedItems
 if ($talsb[0] -ne [System.Windows.Forms.DialogResult]::OK) {
    Write-Host "�û�ȡ���˲���2��"
    exit
 }

##ִ�л�ԭ����
function hy($Tableslist){
$savePaht=$sqlPath  +"\Mysql_file\"


    # ���ӵ�MySQL���ݿ�
    try {
         # ���������ַ���
         $connectionString = "Server=$server;Database=$database;User Id=$username;Password=$password;"
         
         # �����������ݿ�����
         $connection = New-Object MySql.Data.MySqlClient.MySqlConnection($connectionString)
         $connection.Open()
         if ($connection.State -ne [System.Data.ConnectionState]'Open') {
            Write-Host "�޷����ӵ����ݿ⣬�������Ӳ�����"
            exit
         }
        # ��ÿ��ѡ�еı�ִ�л�ԭ
        foreach ($tableName in $Tableslist) {

                $a=$savePaht + "$tableName.sql"
                # ����Ľṹ�����ݱ��浽�������ļ�
               
                $tableSql = Get-Content -Path $a -Raw  -Encoding UTF8
                   
                $query = "SELECT * FROM assets LIMIT 10;"
                $command = New-Object MySql.Data.MySqlClient.MySqlCommand($tableSql, $connection)
                # ִ��SQL�ű�
                $OKis=$command.ExecuteNonQuery() #| Out-Null
                #$dataAdapter = New-Object MySql.Data.MySqlClient.MySqlDataAdapter($command)
                #$dataTable = New-Object System.Data.DataTable
                #$dataAdapter.Fill($dataTable)

                Write-Host "�� $tableName �ѳɹ���ԭ�� $database ���ݿ����ܹ� $OKis ������"
                    
                 # ��ʾ��ѯ���
                 #$dataTable | Format-Table
                 
                 
           
            
            
        }
        # �ر�����
        $connection.Close()
    }
    catch {
        Write-Host "MySQL����: $_"
    }
    finally {
        if ($connection.State -eq 'Open') {
            $connection.Close()
        }
    }
}

foreach ($item in $talsb[1].CheckedItems) {
             
            # ִ�л�ԭʱ�ٴ������û���ѡ��ȷ���Ƿ�Ҫ��ԭ��Ӧ�ı�
            $confirmMessage = "��ѡ�������±���л�ԭ:`n$($item -join ', ')`n`n��ȷ��Ҫ������"
            $confirmResult = [System.Windows.Forms.MessageBox]::Show($confirmMessage, "ȷ�ϻ�ԭ", "YesNo", "Warning")
            

            if ($confirmResult -eq "Yes"){
            
                             
                hy $item
            }
            
    }

    pause