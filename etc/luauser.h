#if defined(__ANDROID__)
#if __ANDROID_API__==19
#if defined(lua_getlocaledecpoint)
#undef lua_getlocaledecpoint
#endif

#define lua_getlocaledecpoint()        ('.')
#endif
#if __ANDROID_API__ < 25
#define fseeko fseek
#define ftello ftell
#endif
#endif
