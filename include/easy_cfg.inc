#if defined _easy_cfg_included
  #endinput
#endif
#define _easy_cfg_included

#define _easy_cfg_has_internal

#if defined _ini_file_included
	#assert "Error! ini_file not supported! Please remove <ini_file> from includes!"
#endif

#include <amxmodx>
#include <amxmisc>

#define ini_read_string internal_ini_read_string
#define ini_write_string internal_ini_write_string
#define ini_read_int internal_ini_read_int
#define ini_write_int internal_ini_write_int
#define ini_read_float internal_ini_read_float
#define ini_write_float internal_ini_write_float

new stock cfg_path[64] = "plugins/easy_cfg.ini";
new stock cfg_max_key_value = -1; // -1 for nolimit

stock cfg_set_path(const path[], max_key_val = -1)
{
	copy(cfg_path,charsmax(cfg_path),path);
	cfg_max_key_value = max_key_val;
}

stock cfg_get_path(path[], len)
{
	new szFile[64]; // as in ini_file
	formatex(szFile[get_configsdir(szFile,charsmax(szFile))], charsmax(szFile), "/%s.ini", cfg_path);
	copy(path,len,szFile);
}

stock cfg_read_str(const section[], const arg[], default_val[], out_val[], outlen)
{
	if (!ini_read_string(cfg_path, section, arg, out_val, outlen))
	{
		ini_write_string(cfg_path, section, arg, default_val);
		copy(out_val,outlen,default_val);
	}
}
stock cfg_read_int(const section[], const arg[], const default_val, &out_val)
{
	if (!ini_read_int(cfg_path, section, arg, out_val))
	{
		ini_write_int(cfg_path, section, arg, default_val);
		out_val = default_val;
	}
}
stock cfg_read_bool(const section[], const arg[], const bool:default_val, &bool:out_val)
{
	static tmp_bool[16];
	if (!ini_read_string(cfg_path, section, arg, tmp_bool, charsmax(tmp_bool)))
	{
		ini_write_string(cfg_path, section, arg, default_val ? "true" : "false");
		out_val = default_val;
	}
	else 
	{
		out_val = equali(tmp_bool,"true") != 0;
	}
}
stock cfg_read_flt(const section[], const arg[], const Float:default_val, &Float:out_val)
{
	if (!ini_read_float(cfg_path, section, arg, out_val))
	{
		ini_write_float(cfg_path, section, arg, default_val);
		out_val = default_val;
	}
}

stock cfg_write_str(const section[], const arg[], val[])
{
	ini_write_string(cfg_path, section, arg, val);
}
stock cfg_write_int(const section[], const arg[], const val)
{
	ini_write_int(cfg_path, section, arg, val);
}
stock cfg_write_bool(const section[], const arg[], const bool:val)
{
	ini_write_string(cfg_path, section, arg, val ? "true" : "false");
}
stock cfg_write_flt(const section[], const arg[], const Float:val)
{
	ini_write_float(cfg_path, section, arg, val);
}

stock cfg_clear()
{
	new szFile[512] = {EOS};
	new hFile = 0;
	
	formatex(szFile[get_configsdir(szFile, charsmax(szFile))], charsmax(szFile), "/%s.ini", cfg_path);
	if (!(hFile = fopen(szFile, "wb")))
		return 0;
		
	fclose(hFile);
	return 1;
}

#if defined _easy_cfg_internal

stock internal_ini_read_int(const file[], const section[], const key[], &value)
{
	new szBuffer[64] = {EOS};
	if (!internal_ini_read(file, section, key, szBuffer, charsmax(szBuffer)))
		return 0;

	value = str_to_num(szBuffer);
	return 1;
}

stock internal_ini_write_int(const file[], const section[], const key[], value)
{
	new szBuffer[64] = {EOS};
	num_to_str(value, szBuffer, charsmax(szBuffer));
	return internal_ini_write(file, section, key, szBuffer);
}

stock internal_ini_read_float(const file[], const section[], const key[], &Float:value)
{
	new szBuffer[64] = {EOS};
	if (!internal_ini_read(file, section, key, szBuffer, charsmax(szBuffer)))
		return 0;

	value = str_to_float(szBuffer);
	return 1;
}

stock internal_ini_write_float(const file[], const section[], const key[], Float:value)
{
	new szBuffer[64] = {EOS};
	formatex(szBuffer, charsmax(szBuffer), "%.5f", value);
	cut_float_better(szBuffer);
	return internal_ini_write(file, section, key, szBuffer);
}

stock internal_ini_read_string(const file[], const section[], const key[], dest[], len)
{
	return internal_ini_read(file, section, key, dest, len);
}

stock internal_ini_write_string(const file[], const section[], const key[], value[])
{
	return internal_ini_write(file, section, key, value);
}

stock internal_ini_copyc(dest[], len, const src[], ch)
{
	copy(dest,len,src);
	for(new i = 0; i < len; i++)
	{
		if (dest[i] == ch)
		{
			dest[i] = EOS;
			return i;
		}
	}
	return -1;
}


stock internal_ini_read(const file[], const section[], const key[], dest[], len)
{
	static var1 = 0,var2 = 0, bool:var3, bool:var4;
	return internal_ini_read_techno(file,section,key,dest,len,var1,var2,var3,var4);
}

#define EASYCFG_BUFFER_CHUNK 512

stock internal_ini_read_techno(const file[], const section[], const key[], dest[], len, &begin_key_offs,&end_key_offs,&bool:sec_found,&bool:key_found)
{
	new hFile = 0;
	new iRetVal = 0;
	new bool:bSectionFound = false;
	new szBuffer[EASYCFG_BUFFER_CHUNK], szFile[512] = {EOS}, szKey[512] = {EOS}, szSection[512] = {EOS};
	new readBytes = 0;
	new curOffset = 0;
	new curEndOffset = 0;

	formatex(szFile[get_configsdir(szFile, charsmax(szFile))], charsmax(szFile), "/%s.ini", file);

	if (!(hFile = fopen(szFile, "rt")))
		return 0;

	while (!feof(hFile))
	{
		begin_key_offs = curOffset = ftell(hFile);
		readBytes = fgets(hFile, szBuffer, charsmax(szBuffer));
		end_key_offs = curEndOffset = ftell(hFile);
		// now begin is first character, end is last character with newline
		
		if (readBytes == 0)
			break;

		trim(szBuffer);

		if (!szBuffer[0] || szBuffer[0] == ';')
			continue;

		if (szBuffer[0] == '[')
		{
			if (bSectionFound)
				break;

			internal_ini_copyc(szSection, charsmax(szSection), szBuffer[1], ']');

			if (equal(section, szSection))
			{
				bSectionFound = true;
				sec_found = true;
			}	
		}

		if (bSectionFound)
		{
			new iSplitPos = contain(szBuffer, "=");

			if (iSplitPos > -1) {
				szBuffer[iSplitPos] = EOS;
				copy(szKey, iSplitPos, szBuffer);
				trim(szKey);
				if (equal(szKey, key)) 
				{
					curOffset += iSplitPos + 1;
					fseek(hFile,curOffset,SEEK_SET);

					new totalLen = curEndOffset-curOffset; 
					
					if (totalLen > len)
						totalLen = len;
					if (cfg_max_key_value > 0 && totalLen > cfg_max_key_value)
						totalLen = cfg_max_key_value;
					
					fread_blocks(hFile,dest,totalLen,BLOCK_BYTE);
					
					totalLen--;
					dest[totalLen] = EOS;
					
					while(totalLen > 0)
					{
						totalLen--;
						if (dest[totalLen] == 10 || dest[totalLen] == 13)
						{
							dest[totalLen] = EOS;
						}
						else break;
					}
					
					trim(dest);
					key_found = true;
					iRetVal = 1;
					break;
				}
			}
		}
	}

	fclose(hFile);
	return iRetVal;
}

stock internal_ini_write(const file[], const section[], const key[], value[])
{
	new hFile = 0;
	static newLine = 10;
	new szBuffer[512] = {EOS}, szFile[512] = {EOS};

	formatex(szFile[get_configsdir(szFile, charsmax(szFile))], charsmax(szFile), "/%s.ini", file);

	new line_beg = 0,line_end = 0, bool:sec_found, bool:key_found;
	internal_ini_read_techno(file,section,key,szBuffer,1,line_beg,line_end,sec_found,key_found);
	
	if (!key_found && sec_found)
	{
		if (!(hFile = fopen(szFile, "a+t")))
			return 0;
		
		// insert new key/val to line_end
		fseek(hFile, line_end, SEEK_SET);
		fprintf(hFile, "%s = %s", key, value);
		fwrite(hFile, newLine, BLOCK_BYTE);
		fclose(hFile);
	}
	else if (key_found)
	{
		if (!(hFile = fopen(szFile, "rt")))
			return 0;
		
		// skip line_beg/line_end and insert new key/val
		static szTempFile[512];
		formatex(szTempFile, charsmax(szTempFile), "%s.tmp", szFile);
		new hTemp = fopen(szTempFile, "wt");

		if (!hTemp)
		{
			fclose(hFile);
			return 0;
		}

		fseek(hFile, 0, SEEK_SET);
		fseek(hTemp, 0, SEEK_SET);
		
		new iBytesToCopy = line_beg;
		while (iBytesToCopy > 0)
		{
			new iChunk = min(charsmax(szBuffer), iBytesToCopy);
			new iRead = fread_blocks(hFile, szBuffer, iChunk, BLOCK_BYTE);
			if (iRead > 0)
			{
				fwrite_blocks(hTemp, szBuffer, iChunk, BLOCK_BYTE);
				iBytesToCopy -= iRead;
			}
			else break;
		}
		
		fseek(hFile, line_end, SEEK_SET);
		fseek(hTemp, line_beg, SEEK_SET);
		
		fprintf(hTemp, "%s = %s", key, value);
		fwrite(hTemp, newLine, BLOCK_BYTE);
		
		while (!feof(hFile))
		{
			new iRead = fread_blocks(hFile, szBuffer, charsmax(szBuffer), BLOCK_BYTE);
			if (iRead > 0)
			{
				fwrite_blocks(hTemp, szBuffer, iRead, BLOCK_BYTE);
			}
		}

		fclose(hFile);
		fclose(hTemp);

		delete_file(szFile);
		rename_file(szTempFile, szFile, 1);
	}
	else
	{	
		if (!(hFile = fopen(szFile, "a+t")))
			return 0;
		fprintf(hFile, "[%s]", section);
		fwrite(hFile, newLine, BLOCK_BYTE);
		fprintf(hFile, "%s = %s", key, value);
		fwrite(hFile, newLine, BLOCK_BYTE);
		fclose(hFile);
	}
	
	return 1;
}

stock cut_float_better(str[])
{
	if (contain(str,".") > 0)
	{
		new len = strlen(str);
		for(new i = len - 1; i > 0; i--)
		{
			if (str[i] == '0')
			{
				str[i] = EOS;
			}
			else if (str[i] == '.')
			{
				str[i] = EOS;
				break;
			}
			else 
			{
				break;
			}
		}
	}
}
#endif