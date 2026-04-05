///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2021, ООО Изи Клауд, https://izi.cloud
// All rights reserved. This program and accompanying materials 
// are subject to license terms Attribution 4.0 International (CC BY 4.0)
// The license text is available here:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////

Function DecompressGZIP(binaryData) Export
	// Get compressed GZIP body
	Stream = BinaryData.OpenStreamForRead();
	Stream.Seek(10, PositionInStream.Begin);
	FileBodyBuffer = New BinaryDataBuffer(Stream.Size()-10);
	Stream.Read(FileBodyBuffer,0,Stream.Size()-18);
	// Get CRC
	CRCBuffer = New BinaryDataBuffer(4);
	Stream.Seek(Stream.Size()-8, PositionInStream.Begin);
	Stream.Read(CRCBuffer,0,4);
	CRC=CRCBuffer.ReadInt32(0);
	// Get uncompressed file size
	UncompressedSizeBuffer = New BinaryDataBuffer(4);
	Stream.Seek(Stream.Size()-4, PositionInStream.Begin);
	Stream.Read(UncompressedSizeBuffer,0,4);
	UncompressedFileSize=UncompressedSizeBuffer.ReadInt32(0);
	// Make valid ZIP structure
	Stream.Close();
	MemoryStream = New MemoryStream(FileBodyBuffer);
	
	CompressedFileName="body.json";
	CompressedFileNameLength	= StrLen(CompressedFileName);
	CompressedFileSize			= MemoryStream.Size();
	FileTime					= 0;
	FileDate					= 0;
	//98 bytes headers, 2 times file length + compressed body size
	ZIPSize = 98 + CompressedFileNameLength*2 + CompressedFileSize;
	BinaryBuffer = New BinaryDataBuffer(ZIPSize);
	// [Local File Header]
	FixedPartLengthLFH = 30;
	
	BinaryBuffer.WriteInt32(0	, 67324752);
	BinaryBuffer.WriteInt16(4	, 20);                      
	BinaryBuffer.WriteInt16(6	, 2050);                    
	BinaryBuffer.WriteInt16(8	, 8);                       
	BinaryBuffer.WriteInt16(10	, FileTime);                
	BinaryBuffer.WriteInt16(12	, FileDate);                
	BinaryBuffer.WriteInt32(14	, CRC);                     
	BinaryBuffer.WriteInt32(18	, CompressedFileSize);      
	BinaryBuffer.WriteInt32(22	, UncompressedFileSize);    
	BinaryBuffer.WriteInt16(26	, CompressedFileNameLength);
	BinaryBuffer.WriteInt16(28	, 0);                       
	
	For i = 0 To CompressedFileNameLength - 1 Do
		BinaryBuffer.Set(FixedPartLengthLFH + i, CharCode(Mid(CompressedFileName, i+1, 1)));
	EndDo;
	
	CompressedDataBuffer = New BinaryDataBuffer(CompressedFileSize);
	
	MemoryStream.Read(CompressedDataBuffer, 0, CompressedFileSize);
	MemoryStream.Close();
	
	BinaryBuffer.Write(FixedPartLengthLFH + CompressedFileNameLength, CompressedDataBuffer);
	
	CurrentOffset = FixedPartLengthLFH + CompressedFileNameLength + CompressedFileSize;

	FixedPartLengthCDFH	= 46;
	AdditionalDataLength= 0;
	
	BinaryBuffer.WriteInt32(CurrentOffset + 0	, 33639248);					
	BinaryBuffer.WriteInt16(CurrentOffset + 4	, 814); 						
	BinaryBuffer.WriteInt16(CurrentOffset + 6	, 20); 							
	BinaryBuffer.WriteInt16(CurrentOffset + 8	, 2050);						
	BinaryBuffer.WriteInt16(CurrentOffset + 10	, 8); 							
	BinaryBuffer.WriteInt16(CurrentOffset + 12	, FileTime); 					
	BinaryBuffer.WriteInt16(CurrentOffset + 14	, FileDate); 					
	BinaryBuffer.WriteInt32(CurrentOffset + 16	, CRC);							
	BinaryBuffer.WriteInt32(CurrentOffset + 20	, CompressedFileSize);			
	BinaryBuffer.WriteInt32(CurrentOffset + 24	, UncompressedFileSize);		
	BinaryBuffer.WriteInt16(CurrentOffset + 28	, CompressedFileNameLength);	
	BinaryBuffer.WriteInt16(CurrentOffset + 30	, AdditionalDataLength);		
	BinaryBuffer.WriteInt16(CurrentOffset + 32	, 0);							
	BinaryBuffer.WriteInt16(CurrentOffset + 34	, 0);							
	BinaryBuffer.WriteInt16(CurrentOffset + 36	, 0);							
	BinaryBuffer.WriteInt32(CurrentOffset + 38	, 2176057344);					
	BinaryBuffer.WriteInt32(CurrentOffset + 42	, 0);							
	
	For i = 0 To CompressedFileNameLength - 1 Do
		BinaryBuffer.Set(CurrentOffset + FixedPartLengthCDFH + i, CharCode(Mid(CompressedFileName, i + 1, 1)));
	EndDo;
	
	CurrentOffset = CurrentOffset + FixedPartLengthCDFH + CompressedFileNameLength;
	CurrentOffset = CurrentOffset + AdditionalDataLength;	
	// [End of central directory record (EOCD)]
	CentralDirectorySize	= FixedPartLengthCDFH + CompressedFileNameLength + AdditionalDataLength;
	CentralDirectoryOffset	= FixedPartLengthLFH  + CompressedFileNameLength + CompressedFileSize;
	
	BinaryBuffer.WriteInt32(CurrentOffset + 0	, 101010256);					
	BinaryBuffer.WriteInt16(CurrentOffset + 4	, 0); 							
	BinaryBuffer.WriteInt16(CurrentOffset + 6	, 0); 							
	BinaryBuffer.WriteInt16(CurrentOffset + 8	, 1); 							
	BinaryBuffer.WriteInt16(CurrentOffset + 10	, 1); 							
	BinaryBuffer.WriteInt32(CurrentOffset + 12	, CentralDirectorySize);		
	BinaryBuffer.WriteInt32(CurrentOffset + 16	, CentralDirectoryOffset);		
	BinaryBuffer.WriteInt16(CurrentOffset + 20	, 0);							
	PathSeparator = GetPathSeparator();
	TempFilesDir  = TempFilesDir() + "GZIP" + PathSeparator;	
	MemoryStream = New MemoryStream(BinaryBuffer);
	File = New ZipFileReader(MemoryStream);
	File.Extract(File.Items[0], TempFilesDir, ZIPRestoreFilePathsMode.DontRestore);
	MemoryStream.Close();
	TextReader = New TextReader(TempFilesDir+CompressedFileName, TextEncoding.UTF8);
	Text = TextReader.Read();
	TextReader.Close();
	DeleteFiles(TempFilesDir);
	Return Text;	
EndFunction

Function InsertAttribute(XMLString, nodeName, attributeName, attributeValue) Export
	
	XMLReader = New XMLReader;
	XMLReader.SetString(XMLString);
	DOMBuilder = Новый DOMBuilder;
	Document = DOMBuilder.Read(XMLReader);
	XMLReader.Close();
	
	Nodes = Document.GetElementByTagName(NodeName);
	For each Node In Nodes Do
		Node.SetAttribute(AttributeName, AttributeValue);
	EndDo;
	
	XMLWriter = New XMLWriter;
	XMLWriter.SetString();	
	DOMWriter = New DOMWriter;
	DOMWriter.Write(Document, XMLWriter);	
	Return XMLWriter.Close();
	
EndFunction

Function InsertAttr(XMLString, nodeName, attributeName, attributeValue) Export

	XMLString = StrReplace(
		XMLString,
		StrTemplate("<%1 ", nodeName),
		StrTemplate("<%1 %2=""%3"" ", nodeName, attributeName, attributeValue)
	);
	
	XMLString = StrReplace(
		XMLString,
		StrTemplate("<%1>", nodeName),
		StrTemplate("<%1 %2=""%3"">", nodeName, attributeName, attributeValue)
	);
	
	Return XMLString;
	
EndFunction

Function GetIikoHeaders(parameters, isGzip = True) Export
	
	HTTPHeaders = New Map;
	HTTPHeaders.Insert("Content-Type", 			"text/xml");
	HTTPHeaders.Insert("X-Resto-LoginName", 	Parameters.user);
	HTTPHeaders.Insert("X-Resto-PasswordHash", 	like_CommonAtServer.GetHash(Parameters.password));
	HTTPHeaders.Insert("X-Resto-BackVersion", 	Parameters.version);
	HTTPHeaders.Insert("X-Resto-AuthType", 		"BACK");
	HTTPHeaders.Insert("X-Resto-ServerEdition", Parameters.edition);
	HTTPHeaders.Insert("Accept-Encoding", 		?(isGzip, "gzip", "none"));
	
	Return HTTPHeaders;
	
EndFunction

Function IikoDateTimeTo1C(iikoDT) Export
	
	dtParts  = StrSplit(iikoDT, 	  ".");
	dateTime = StrSplit(dtParts[0],  "T");
	date 	 = StrReplace(dateTime[0], "-", "");
	time 	 = StrReplace(dateTime[1], ":", "");
	Return Date(date+time);
	
EndFunction

Function Translit(input) Export
	
    rus = "абвгдеёжзийклмнопрстуфхцчшщьыъэюяАБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЬЫЪЭЮЯ";
    eng = "a;b;v;g;d;e;yo;zh;z;i;y;k;l;m;n;o;p;r;s;t;u;f;kh;ts;ch;sh;shch;;y;;e;yu;ya;A;B;V;G;D;E;Yo;Zh;Z;I;Y;K;L;M;N;O;P;R;S;T;U;F;Kh;Ts;Ch;Sh;Shch;;Y;;E;Yu;Ya";
    engArray 	= StrSplit(eng,";");
    inputLength = StrLen(input);
    output = "";
	
    For a=1 To inputLength Do    
        currentChar = Mid(input, a, 1);    
        position = Find(rus, currentChar);
        If position > 0 Then 
            output = output + engArray[position-1];
        Else 
            output = output + currentChar;
        EndIf;
	EndDo;
	
    Return output; 
	
EndFunction

Procedure UsrMessage(message) Export
	
	userMessage = New UserMessage;
	userMessage.Text = message;
	userMessage.Message();
	 
EndProcedure