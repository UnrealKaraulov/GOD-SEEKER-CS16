#define _easy_cfg_has_internal

#if !defined _easy_cfg_internal
#if !defined _ini_file_included
	#include <ini_file>
#endif
#else 
	#include <amxmodx>
	#include <amxmisc>
	
	#define ini_read_string internal_ini_read_string
	#define ini_write_string internal_ini_write_string
	#define ini_read_int internal_ini_read_int
	#define ini_write_int internal_ini_write_int
	#define ini_read_float internal_ini_read_float
	#define ini_write_float internal_ini_write_float
#endif

new stock cfg_path[64] = "plugins/easy_cfg.ini";

stock cfg_set_path(const path[])
{
	copy(cfg_path,charsmax(cfg_path),path);
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
	new hFile = 0;
	new iRetVal = 0;
	new bool:bSectionFound = false;
	new szBuffer[512] = {EOS}, szFile[512] = {EOS}, szKey[64] = {EOS}, szSection[64] = {EOS};

	formatex(szFile[get_configsdir(szFile, charsmax(szFile))], charsmax(szFile), "/%s.ini", file);

	if (!(hFile = fopen(szFile, "rt")))
		return 0;

	while (!feof(hFile))
	{
		if (fgets(hFile, szBuffer, charsmax(szBuffer)) == 0)
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
				bSectionFound = true;
		}

		if (bSectionFound)
		{
			split(szBuffer, szKey, charsmax(szKey), szBuffer, charsmax(szBuffer), "=");
			trim(szKey);
			trim(szBuffer);

			if (equal(szKey, key))
				iRetVal = copy(dest, len, szBuffer);
		}
	}

	fclose(hFile);
	return iRetVal;
}

stock internal_ini_write(const file[], const section[], const key[], value[])
{
	new hFile = 0, hTempFile = 0;
	new bool:bSectionExists = false, bool:bKeyExists = false, bool:bReplace = false;
	new iKeyPosStart = 0, iKeyPosEnd = 0;
	new szBuffer[512] = {EOS}, szFile[64] = {EOS}, szTempFile[64] = {EOS}, szKey[64] = {EOS}, szSection[64] = {EOS};

	formatex(szFile[get_configsdir(szFile, charsmax(szFile))], charsmax(szFile), "/%s.ini", file);
	bReplace = true;

	if (!(hFile = fopen(szFile, "a+t")))
		return 0;

	while (!feof(hFile))
	{
		if (fgets(hFile, szBuffer, charsmax(szBuffer)) == 0)
			break;

		trim(szBuffer);

		if (szBuffer[0] == '[')
		{
			internal_ini_copyc(szSection, charsmax(szSection), szBuffer[1], ']');

			if (equal(section, szSection))
			{
				bSectionExists = true;
				break;
			}
		}
	}

	if (!bSectionExists)
	{
		fprintf(hFile, "^n[%s]^n%s = %s^n", section, key, value);
		fclose(hFile);
		return 1;
	}

	while (!feof(hFile))
	{
		iKeyPosStart = ftell(hFile);

		if (fgets(hFile, szBuffer, charsmax(szBuffer)) == 0)
			break;

		trim(szBuffer);

		if (szBuffer[0] == '[')
			break;

		if (!szBuffer[0] || szBuffer[0] == ';')
			continue;

		split(szBuffer, szKey, charsmax(szKey), szBuffer, charsmax(szBuffer), "=");
		trim(szKey);
		trim(szBuffer);

		iKeyPosEnd = ftell(hFile);

		if (equal(szKey, key))
		{
			bKeyExists = true;
			break;
		}
	}

	if (!bKeyExists)
	{
		if (feof(hFile))
		{
			fprintf(hFile, "%s = %s^n", key, value);
			fclose(hFile);
			return 1;
		}

		bReplace = false;
	}

	formatex(szTempFile[get_configsdir(szTempFile, charsmax(szTempFile))], charsmax(szTempFile), "/ini_file_temp.ini");
	hTempFile = fopen(szTempFile, "wt");

	if (!hTempFile)
	{
		fclose(hTempFile);
		fclose(hFile);
		return 0;
	}

	if (!bReplace)
	{
		fseek(hFile, 0, SEEK_SET);

		while (ftell(hFile) < iKeyPosEnd)
		{
			fgets(hFile, szBuffer, charsmax(szBuffer));
			fputs(hTempFile, szBuffer);
		}
	}
	else
	{
		fseek(hFile, 0, SEEK_SET);

		while (ftell(hFile) < iKeyPosStart)
		{
			fgets(hFile, szBuffer, charsmax(szBuffer));
			fputs(hTempFile, szBuffer);
		}

		fgets(hFile, szBuffer, charsmax(szBuffer));
	}

	fprintf(hTempFile, "%s = %s^n", key, value);

	while (!feof(hFile))
	{
		fgets(hFile, szBuffer, charsmax(szBuffer));
		fputs(hTempFile, szBuffer);
	}

	fclose(hFile);
	fclose(hTempFile);

	delete_file(szFile);

	if (!rename_file(szTempFile, szFile, 1))
		return 0;

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