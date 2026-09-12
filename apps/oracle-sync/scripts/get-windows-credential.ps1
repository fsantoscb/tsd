param([Parameter(Mandatory=$true)][string]$Target)
$source=@'
using System; using System.Runtime.InteropServices;
public static class CredentialReader {
 [StructLayout(LayoutKind.Sequential,CharSet=CharSet.Unicode)] public struct Credential { public uint Flags,Type; public string TargetName,Comment; public System.Runtime.InteropServices.ComTypes.FILETIME LastWritten; public uint CredentialBlobSize; public IntPtr CredentialBlob; public uint Persist,AttributeCount; public IntPtr Attributes; public string TargetAlias,UserName; }
 [DllImport("advapi32.dll",EntryPoint="CredReadW",CharSet=CharSet.Unicode,SetLastError=true)] public static extern bool Read(string target,uint type,uint flags,out IntPtr pointer);
 [DllImport("advapi32.dll")] public static extern void Free(IntPtr pointer);
}
'@
Add-Type $source
$pointer=[IntPtr]::Zero
if(-not [CredentialReader]::Read($Target,1,0,[ref]$pointer)){throw "Windows credential not found"}
try {
 $credential=[Runtime.InteropServices.Marshal]::PtrToStructure($pointer,[type][CredentialReader+Credential])
 $password=[Runtime.InteropServices.Marshal]::PtrToStringUni($credential.CredentialBlob,[int]($credential.CredentialBlobSize/2))
 @{username=$credential.UserName;password=$password}|ConvertTo-Json -Compress
} finally { if($pointer-ne[IntPtr]::Zero){[CredentialReader]::Free($pointer)} }
