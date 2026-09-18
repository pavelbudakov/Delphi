unit uConstants;

interface

Const
     clBase = $FAF8F3;
     clInputs = $EFEADF;
     clDividers = $DDD0BC;
     clButtons = $BFA085;
     clBaseText = $F5F3E9;
     clAltBaseText = $FAF8F3;
     clTextHighLight = $A88B73;

     MSG_NOT_CONNECTED : WideString = 'Соединение не установлено';
     MSG_NOT_FOUND     : WideString = 'Записи не найдены';

     cCONFIGURATION_FILE = '.\appsettings.json';
     cCLIENT_CONFIGURATION_FILE = '.\appsettings.client.json';

     cSIGNATURE          = '{"signature": "SearchInform (c)2026"}';

     QRY_GET_USERS_ALL =
'SELECT ut.GroupID, u.* FROM [dbo].[UserTree] ut ' +
'INNER JOIN [dbo].[UserList] u ON u.UserID = ut.UserID ';

     QRY_GET_USER_BY_USERID =
'SELECT ut.GroupID, u.* FROM [dbo].[UserTree] ut ' +
'INNER JOIN [dbo].[UserList] u ON u.UserID = ut.UserID '+
'WHERE ut.UserID = :ID';

     QRY_GET_USERS_BY_GROUP_DIRECT =
'SELECT * FROM [dbo].[UserTree] ut ' +
'INNER JOIN [dbo].[UserList] u ON u.UserID = ut.UserID ' +
'WHERE ut.GroupID = :ID';

     QRY_GET_GROUPS_ALL =
'SELECT *, ' +
'(SELECT COUNT(1) FROM [dbo].[GroupTree] gt WHERE gt.ParentID = g.GroupID) AS GroupCount, ' +
'(SELECT COUNT(1) FROM [dbo].[UserTree] ut WHERE ut.GroupID = g.GroupID) AS UserCount ' +
'FROM [dbo].[GroupList] g ';

     QRY_GET_GROUP_BY_GROUPID =
'SELECT *, ' +
'(SELECT COUNT(1) FROM [dbo].[GroupTree] gt WHERE gt.ParentID = g.GroupID) AS GroupCount, ' +
'(SELECT COUNT(1) FROM [dbo].[UserTree] ut WHERE ut.GroupID = g.GroupID) AS UserCount ' +
'FROM [dbo].[GroupList] g ' +
'WHERE GroupID = :ID';

     QRY_GET_GROUP_BY_GROUPID_NESTED =
'DECLARE @GroupID INT = :id; '#13#10 +
' '#13#10 +
'CREATE TABLE #SubGroups ( '#13#10 +
'    GroupID INT PRIMARY KEY '#13#10 +
'); '#13#10 +
' '#13#10 +
'INSERT INTO #SubGroups (GroupID) VALUES (@GroupID); '#13#10 +
' '#13#10 +
'WHILE 1 = 1 '#13#10 +
'BEGIN '#13#10 +
'    INSERT INTO #SubGroups (GroupID) '#13#10 +
'    SELECT DISTINCT gt.GroupID '#13#10 +
'    FROM GroupTree gt '#13#10 +
'    INNER JOIN #SubGroups sg ON gt.ParentID = sg.GroupID '#13#10 +
'    WHERE gt.ParentID <> 0 '#13#10 +
'      AND NOT EXISTS ( '#13#10 +
'          SELECT 1 FROM #SubGroups sg2 '#13#10 +
'          WHERE sg2.GroupID = gt.GroupID '#13#10 +
'      ); '#13#10 +
' '#13#10 +
'    IF @@ROWCOUNT = 0 BREAK; '#13#10 +
'END; '#13#10 +
' '#13#10 +
'SELECT '#13#10 +
'    ut.GroupID, '#13#10 +
'    ul.UserID, '#13#10 +
'    ul.DisplayName, '#13#10 +
'    ul.Photo, '#13#10 +
'    ul.Phone, '#13#10 +
'    ul.Address, '#13#10 +
'    ul.Note '#13#10 +
'FROM UserTree ut '#13#10 +
'INNER JOIN UserList ul ON ut.UserID = ul.UserID '#13#10 +
'WHERE ut.GroupID IN (SELECT GroupID FROM #SubGroups) '#13#10 +
'ORDER BY ul.DisplayName; '#13#10 +
' '#13#10 +
'DROP TABLE #SubGroups; ';


     QRY_GET_USERS_BY_GROUPID_NESTED =
'DECLARE @GroupID INT = :ID; '#13#10 +
' '#13#10 +
'CREATE TABLE #SubGroups ( '#13#10 +
'    GroupID INT PRIMARY KEY, '#13#10 +
'    Path NVARCHAR(MAX) NOT NULL '#13#10 +
'); '#13#10 +
' '#13#10 +
'INSERT INTO #SubGroups (GroupID, Path) '#13#10 +
'SELECT '#13#10 +
'    GroupID, '#13#10 +
'    CAST(GroupID AS NVARCHAR) + N'' '' + DisplayName '#13#10 +
'FROM GroupList '#13#10 +
'WHERE GroupID = @GroupID; '#13#10 +
' '#13#10 +
'WHILE 1 = 1 '#13#10 +
'BEGIN '#13#10 +
'    INSERT INTO #SubGroups (GroupID, Path) '#13#10 +
'    SELECT DISTINCT '#13#10 +
'        gt.GroupID, '#13#10 +
'        sg.Path + N'' -> '' + CAST(gt.GroupID AS NVARCHAR) + N'' '' + gl.DisplayName '#13#10 +
'    FROM #SubGroups sg '#13#10 +
'    INNER JOIN GroupTree gt ON sg.GroupID = gt.ParentID '#13#10 +
'    INNER JOIN GroupList gl ON gt.GroupID = gl.GroupID '#13#10 +
'    WHERE gt.ParentID <> 0 '#13#10 +
'      AND NOT EXISTS ( '#13#10 +
'          SELECT 1 FROM #SubGroups sg2 '#13#10 +
'          WHERE sg2.GroupID = gt.GroupID '#13#10 +
'      ); '#13#10 +
' '#13#10 +
'    IF @@ROWCOUNT = 0 BREAK; '#13#10 +
'END; '#13#10 +
' '#13#10 +
'WITH UserPaths AS ( '#13#10 +
'    SELECT '#13#10 +
'        ul.AccountEnabled, '#13#10 +
'        ul.UserID, '#13#10 +
'        ut.GroupID, '#13#10 +
'        gl.DisplayName AS GroupDisplayName, '#13#10 +
'        ul.DisplayName, '#13#10 +
'        ul.Photo, '#13#10 +
'        ul.Phone, '#13#10 +
'        ul.Address, '#13#10 +
'        ul.Note, '#13#10 +
'        CAST( '#13#10 +
'        ( '#13#10 +
'            SELECT STRING_AGG(sg2.Path, N''; '') WITHIN GROUP (ORDER BY sg2.Path) '#13#10 +
'            FROM #SubGroups sg2 '#13#10 +
'            INNER JOIN UserTree ut2 ON sg2.GroupID = ut2.GroupID '#13#10 +
'            WHERE ut2.UserID = ul.UserID '#13#10 +
'		) '#13#10 +
'        AS NVARCHAR(1000)) AS GroupPath, '#13#10 +
'        ROW_NUMBER() OVER (PARTITION BY ul.UserID ORDER BY ut.GroupID) AS rn '#13#10 +
'    FROM UserTree ut '#13#10 +
'    INNER JOIN UserList ul ON ut.UserID = ul.UserID '#13#10 +
'    INNER JOIN GroupList gl ON ut.GroupID = gl.GroupID '#13#10 +
'    INNER JOIN #SubGroups sg ON ut.GroupID = sg.GroupID '#13#10 +
') '#13#10 +
'SELECT * '#13#10 +
'FROM UserPaths '#13#10 +
'WHERE rn = 1 '#13#10 +
'ORDER BY DisplayName; '#13#10 +
' '#13#10 +
'DROP TABLE #SubGroups; ';

implementation

end.
