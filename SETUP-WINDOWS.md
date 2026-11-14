# SupportSphere — Windows setup

```powershell
cd "D:\Sem 5\JAVA\SupportSphere"
mvn clean javafx:run
```

Check MySQL service:
```powershell
Get-Service MySQL80
```
Start it if required:
```powershell
Start-Service MySQL80
```

Do not rerun `schema.sql` every time you launch the app.
