#if defined _easy_cfg_included
  #endinput
#endif
#define _easy_cfg_included

#if defined _ini_file_included
	#assert "Error! ini_file not supported! Please remove <ini_file> from includes!"
#endif

#include <amxmodx>
#include <amxmisc>

// Define to enable debug tracing
//#define EASY_CFG_DEBUG

#define ini_read_string internal_ini_read_string
#define ini_write_string internal_ini_write_string
#define ini_read_int internal_ini_read_int
#define ini_write_int internal_ini_write_int
#define ini_read_float internal_ini_read_float
#define ini_write_float internal_ini_write_float

new stock cfg_path[512] = "plugins/easy_cfg";
new stock cfg_max_key_value = -1; // -1 for nolimit
new stock rnd_value = 0;

stock const endline_code = 10;
stock const endreturn_code = 13;

#if defined EASY_CFG_DEBUG
stock cfg_debug(const fmt_str[], any:...)
{
	static debug_msg[512];
	vformat(debug_msg, charsmax(debug_msg), fmt_str, 2);
	log_amx("[EASY_CFG_DEBUG] %s", debug_msg);
	server_print("[EASY_CFG_DEBUG] %s", debug_msg);
}
#endif

stock bool:cfg_set_path(const path[], max_key_val = -1)
{
	copy(cfg_path,charsmax(cfg_path),path);
	cfg_max_key_value = max_key_val;
	
	rnd_value = random(3);
	
	#if defined EASY_CFG_DEBUG
	cfg_debug("=== CFG_INIT: path='%s', max_key_val=%d", path, max_key_val);
	#endif

	new szFile[512] = {EOS};
	formatex(szFile[get_configsdir(szFile, charsmax(szFile))], charsmax(szFile), "/%s.ini", cfg_path);
	
	new hFile = fopen(szFile, "rb");
	if (!hFile) 
	{
		hFile = fopen(szFile, "wb");
		if (hFile)
		{
			fclose(hFile);
			return true;
		}
		else 
		{
			log_error(AMX_ERR_NONE, "[EASYCFG] NO ACCESS TO %s!!!", szFile);
			return false;
		}
	}
	else 
	{
		fclose(hFile);
		return true;
	}
}

stock bool:cfg_get_path(path[], const len)
{
	new szFile[512];
	formatex(szFile[get_configsdir(szFile,charsmax(szFile))], charsmax(szFile), "/%s.ini", cfg_path);
	copy(path,len,szFile);
	return true;
}

stock bool:cfg_clear()
{
	new szFile[512] = {EOS};
	new hFile = 0;
	
	formatex(szFile[get_configsdir(szFile, charsmax(szFile))], charsmax(szFile), "/%s.ini", cfg_path);
	
	#if defined EASY_CFG_DEBUG
	cfg_debug("CLEAR: file '%s'", szFile);
	#endif
	
	hFile = fopen(szFile, "wb");
	
	if (!hFile)
		return false;
	
	fclose(hFile);
	return true;
}

stock bool:cfg_read_str(const section[], const arg[], const default_val[], out_val[], const outlen)
{
	#if defined EASY_CFG_DEBUG
	cfg_debug("READ_STR: section='%s', key='%s', default='s'", section, arg, default_val);
	#endif
	
	if (!ini_read_string(cfg_path, section, arg, out_val, outlen))
	{
		ini_write_string(cfg_path, section, arg, default_val);
		copy(out_val,outlen,default_val);
		
		#if defined EASY_CFG_DEBUG
		cfg_debug("READ_STR: NOT_FOUND -> wrote default: '%s'", default_val);
		#endif
		
		return false;
	}
	
	return true;
}

stock bool:cfg_read_int(const section[], const arg[], const default_val, &out_val)
{
	#if defined EASY_CFG_DEBUG
	cfg_debug("READ_INT: section='%s', key='%s', default=%d", section, arg, default_val);
	#endif
	
	if (!ini_read_int(cfg_path, section, arg, out_val))
	{
		ini_write_int(cfg_path, section, arg, default_val);
		out_val = default_val;
		
		#if defined EASY_CFG_DEBUG
		cfg_debug("READ_INT: NOT_FOUND -> wrote default: %d", default_val);
		#endif
		
		return false;
	}
	
	#if defined EASY_CFG_DEBUG
	cfg_debug("READ_INT: FOUND -> value: %d", out_val);
	#endif
	
	return true;
}

stock bool:cfg_read_bool(const section[], const arg[], const bool:default_val, &bool:out_val)
{
	static tmp_bool[16];
	
	#if defined EASY_CFG_DEBUG
	cfg_debug("READ_BOOL: section='%s', key='%s'", section, arg);
	#endif
	
	if (!ini_read_string(cfg_path, section, arg, tmp_bool, charsmax(tmp_bool)))
	{
		ini_write_string(cfg_path, section, arg, default_val ? "true" : "false");
		out_val = default_val;
		
		#if defined EASY_CFG_DEBUG
		cfg_debug("READ_BOOL: NOT_FOUND -> wrote default: %s", default_val ? "true" : "false");
		#endif
		
		return false;
	}
	else 
	{
		out_val = equali(tmp_bool,"true") != 0;
		return true;
	}
}

stock bool:cfg_read_flt(const section[], const arg[], const Float:default_val, &Float:out_val)
{
	#if defined EASY_CFG_DEBUG
	cfg_debug("READ_FLOAT: section='%s', key='%s', default=%.2f", section, arg, default_val);
	#endif
	
	if (!ini_read_float(cfg_path, section, arg, out_val))
	{
		ini_write_float(cfg_path, section, arg, default_val);
		out_val = default_val;
		
		#if defined EASY_CFG_DEBUG
		cfg_debug("READ_FLOAT: NOT_FOUND -> wrote default: %.2f", default_val);
		#endif
		
		return false;
	}
	
	#if defined EASY_CFG_DEBUG
	cfg_debug("READ_FLOAT: FOUND -> value: %.2f", out_val);
	#endif
	
	return true;
}

stock bool:cfg_write_str(const section[], const arg[], const val[])
{
	#if defined EASY_CFG_DEBUG
	cfg_debug("WRITE_STR: section='%s', key='%s', val='%s'", section, arg, val);
	#endif
	
	return ini_write_string(cfg_path, section, arg, val);
}

stock bool:cfg_write_int(const section[], const arg[], const val)
{
	#if defined EASY_CFG_DEBUG
	cfg_debug("WRITE_INT: section='%s', key='%s', val=%d", section, arg, val);
	#endif
	
	return ini_write_int(cfg_path, section, arg, val);
}

stock bool:cfg_write_bool(const section[], const arg[], const bool:val)
{
	#if defined EASY_CFG_DEBUG
	cfg_debug("WRITE_BOOL: section='%s', key='%s', val=%s", section, arg, val ? "true" : "false");
	#endif
	
	return ini_write_string(cfg_path, section, arg, val ? "true" : "false");
}

stock bool:cfg_write_flt(const section[], const arg[], const Float:val)
{
	#if defined EASY_CFG_DEBUG
	cfg_debug("WRITE_FLOAT: section='%s', key='%s', val=%.2f", section, arg, val);
	#endif
	
	return ini_write_float(cfg_path, section, arg, val);
}

// ==================== INTERNAL FUNCTIONS ====================

stock bool:internal_ini_read_int(const file[], const section[], const key[], &value)
{
	new szBuffer[64] = {EOS};
	if (!internal_ini_read(file, section, key, szBuffer, charsmax(szBuffer)))
		return false;

	value = str_to_num(szBuffer);
	return true;
}

stock bool:internal_ini_write_int(const file[], const section[], const key[], const value)
{
	new szBuffer[64] = {EOS};
	num_to_str(value, szBuffer, charsmax(szBuffer));
	return internal_ini_write(file, section, key, szBuffer);
}

stock bool:internal_ini_read_float(const file[], const section[], const key[], &Float:value)
{
	new szBuffer[64] = {EOS};
	if (!internal_ini_read(file, section, key, szBuffer, charsmax(szBuffer)))
		return false;

	value = str_to_float(szBuffer);
	return true;
}

stock bool:internal_ini_write_float(const file[], const section[], const key[], const Float:value)
{
	new szBuffer[64] = {EOS};
	formatex(szBuffer, charsmax(szBuffer), "%.5f", value);
	cut_float_better(szBuffer);
	return internal_ini_write(file, section, key, szBuffer);
}

stock bool:internal_ini_read_string(const file[], const section[], const key[], dest[], const len)
{
	return internal_ini_read(file, section, key, dest, len);
}

stock bool:internal_ini_write_string(const file[], const section[], const key[], const value[])
{
	return internal_ini_write(file, section, key, value);
}

stock internal_ini_copyc(dest[], const len, const src[], ch)
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

stock bool:internal_ini_read(const file[], const section[], const key[], dest[], const len)
{
	new var1 = 0,var2 = 0, bool:var3, bool:var4;
	return internal_ini_read_techno(file,section,key,dest,len,var1,var2,var3,var4);
}

#define EASYCFG_BUFFER_CHUNK 512

stock bool:internal_ini_read_techno(const file[], const section[], const key[], dest[], const len, &begin_key_offs,&end_key_offs,&bool:sec_found,&bool:key_found)
{
	new hFile = 0;
	new bool:bRetVal = false;
	new bool:bSectionFound = false;
	new szBuffer[EASYCFG_BUFFER_CHUNK], szFile[512] = {EOS}, szKey[512] = {EOS}, szSection[512] = {EOS};
	new readBytes = 0;
	new curOffset = 0;
	new curEndOffset = 0;

	formatex(szFile[get_configsdir(szFile, charsmax(szFile))], charsmax(szFile), "/%s.ini", file);

	#if defined EASY_CFG_DEBUG
	cfg_debug("INTERNAL_READ: file='%s', section='%s', key='%s'", file, section, key);
	#endif

	hFile = fopen(szFile, "rt");
	
	if (!hFile)
	{
		#if defined EASY_CFG_DEBUG
		cfg_debug("INTERNAL_READ: FAILED to open file");
		#endif
		return false;
	}

	while (!feof(hFile))
	{
		begin_key_offs = curOffset = ftell(hFile);
		readBytes = fgets(hFile, szBuffer, charsmax(szBuffer));
		end_key_offs = curEndOffset = ftell(hFile);
		
		if (readBytes == 0)
			break;

		trim(szBuffer);

		if (!szBuffer[0] || szBuffer[0] == ';')
			continue;

		if (szBuffer[0] == '[')
		{
			if (bSectionFound)
			{	
				end_key_offs = curEndOffset = begin_key_offs;
				#if defined EASY_CFG_DEBUG
				cfg_debug("INTERNAL_READ: leaving section at offset %d", curOffset);
				#endif
				break;
			}

			internal_ini_copyc(szSection, charsmax(szSection), szBuffer[1], ']');
			trim(szSection);

			if (equali(section, szSection))
			{
				bSectionFound = true;
				sec_found = true;
				#if defined EASY_CFG_DEBUG
				cfg_debug("INTERNAL_READ: TARGET_SECTION_FOUND at offset %d", curOffset);
				#endif
			}	
		}

		if (bSectionFound)
		{
			new iSplitPos = contain(szBuffer, "=");

			if (iSplitPos > -1) {
				szBuffer[iSplitPos] = EOS;
				copy(szKey, iSplitPos, szBuffer);
				trim(szKey);
				
				if (equali(szKey, key)) 
				{
					key_found = true;
					curOffset += iSplitPos + 1;
					fseek(hFile,curOffset,SEEK_SET);

					new totalLen = curEndOffset-curOffset;
					if (totalLen <= 0)
					{
						bRetVal = false;
						break;
					}
					
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
						if (dest[totalLen] == endline_code || dest[totalLen] == endreturn_code)
						{
							dest[totalLen] = EOS;
						}
						else break;
					}
					
					trim(dest);
					bRetVal = true;
					
					#if defined EASY_CFG_DEBUG
					cfg_debug("INTERNAL_READ: KEY_FOUND at pos %d-%d, value='%s'", 
						begin_key_offs, end_key_offs, dest);
					#endif
					
					break;
				}
			}
		}
	}

	fclose(hFile);
	
	#if defined EASY_CFG_DEBUG
	if (!bRetVal)
	{
		cfg_debug("INTERNAL_READ: KEY_NOT_FOUND (section_found=%d, key_found=%d)", 
			sec_found, key_found);
	}
	#endif
	
	return bRetVal;
}

stock bool:internal_ini_write(const file[], const section[], const key[], const value[])
{
	new hFile = 0;
	new szBuffer[512] = {EOS}, szFile[512] = {EOS};

	formatex(szFile[get_configsdir(szFile, charsmax(szFile))], charsmax(szFile), "/%s.ini", file);

	#if defined EASY_CFG_DEBUG
	cfg_debug("INTERNAL_WRITE: file='%s', section='%s', key='%s', value='%s'", 
		file, section, key, value);
	#endif

	new line_beg = 0,line_end = 0, bool:sec_found, bool:key_found;
	internal_ini_read_techno(file,section,key,szBuffer,charsmax(szBuffer),line_beg,line_end,sec_found,key_found);
	
	#if defined EASY_CFG_DEBUG
	cfg_debug("INTERNAL_WRITE: positions -> beg=%d, end=%d, sec_found=%d, key_found=%d", 
		line_beg, line_end, sec_found, key_found);
	#endif
	
	// Вставка нового ключа внутрь существующей секции (ключ отсутствует)
	if (sec_found || key_found)
	{
		#if defined EASY_CFG_DEBUG
		cfg_debug("INTERNAL_WRITE: REPLACING_VALUE from %d to %d, new='%s'", line_beg, line_end,value);
		#endif
		
		hFile = fopen(szFile, "rt");

		if (!hFile)
			return false;
		
		static szTempFile[512];
		formatex(szTempFile, charsmax(szTempFile), "%s(%i).tmp", szFile,rnd_value);
		delete_file(szTempFile);
		
		new hTemp = fopen(szTempFile, "wt");

		if (!hTemp)
		{
			fclose(hFile);
			return false;
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
				fwrite_blocks(hTemp, szBuffer, iRead, BLOCK_BYTE);
				iBytesToCopy -= iRead;
			}
			else break;
		}
		
		fseek(hFile, line_end, SEEK_SET);
		fseek(hTemp, line_beg, SEEK_SET);
		
		fprintf(hTemp, "%s = %s", key, value);
		
		fwrite(hTemp, endline_code, BLOCK_BYTE);
		
		while (!feof(hFile))
		{
			new iRead = fread_blocks(hFile, szBuffer, charsmax(szBuffer), BLOCK_BYTE);
			if (iRead > 0)
			{
				fwrite_blocks(hTemp, szBuffer, iRead, BLOCK_BYTE);
			}
		}

		fflush(hTemp);
		fclose(hTemp);
		
		fflush(hFile);
		fclose(hFile);

		delete_file(szFile);
		rename_file(szTempFile, szFile, 1);
		delete_file(szTempFile);
	}
	else
	{   
		#if defined EASY_CFG_DEBUG
		cfg_debug("INTERNAL_WRITE: CREATING_NEW_SECTION");
		#endif

		hFile = fopen(szFile, "a+t");

		if (!hFile)
		{
			return false;
		}
		fprintf(hFile, "[%s]", section);
		fwrite(hFile, endline_code, BLOCK_BYTE);
		fprintf(hFile, "%s = %s", key, value);
		fwrite(hFile, endline_code, BLOCK_BYTE);
		fflush(hFile);
		fclose(hFile);
	}
	
	return true;
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