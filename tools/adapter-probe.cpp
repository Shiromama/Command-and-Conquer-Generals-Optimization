// Adapter probe for SAGE/D3D8 on hybrid laptops.
//
// The engine creates its device with D3DADAPTER_DEFAULT. This probe prints what the
// D3D8 *and* D3D9 runtimes enumerate, which decides whether source-level adapter
// selection can pick a discrete GPU at all, and whether Windows' per-app
// "High performance" preference (HKCU\Software\Microsoft\DirectX\UserGpuPreferences)
// is honored.
//
// Build (32-bit):
//   cl /nologo /EHsc /I<dx8 sdk> /Fe:build\adapter-probe.exe tools\adapter-probe.cpp
// Both runtimes are loaded dynamically so no import library is required.

#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <d3d8.h>
#include <d3d9.h>
#include <stdio.h>

typedef IDirect3D8 *(WINAPI *PFN_Direct3DCreate8)(UINT);
typedef IDirect3D9 *(WINAPI *PFN_Direct3DCreate9)(UINT);

static void probe_d3d8()
{
	HMODULE lib = LoadLibraryA("d3d8.dll");
	if (lib == nullptr)
	{
		printf("D3D8: d3d8.dll not loadable (error %lu)\n", GetLastError());
		return;
	}
	PFN_Direct3DCreate8 create = (PFN_Direct3DCreate8)GetProcAddress(lib, "Direct3DCreate8");
	IDirect3D8 *d3d = create ? create(D3D_SDK_VERSION) : nullptr;
	if (d3d == nullptr)
	{
		printf("D3D8: Direct3DCreate8 failed\n");
		return;
	}

	printf("D3D8: adapters=%u\n", d3d->GetAdapterCount());
	for (UINT i = 0; i < d3d->GetAdapterCount(); ++i)
	{
		D3DADAPTER_IDENTIFIER8 id;
		ZeroMemory(&id, sizeof(id));
		d3d->GetAdapterIdentifier(i, D3DENUM_NO_WHQL_LEVEL, &id);
		D3DCAPS8 caps;
		ZeroMemory(&caps, sizeof(caps));
		HRESULT capsHr = d3d->GetDeviceCaps(i, D3DDEVTYPE_HAL, &caps);
		printf("D3D8 [%u] vendor=0x%04X device=0x%04X capsHr=0x%08lX desc=\"%s\" modes=%u\n",
			i, id.VendorId, id.DeviceId, (unsigned long)capsHr, id.Description,
			d3d->GetAdapterModeCount(i));
	}
	d3d->Release();
	FreeLibrary(lib);
}

static void probe_d3d9()
{
	HMODULE lib = LoadLibraryA("d3d9.dll");
	if (lib == nullptr)
	{
		printf("D3D9: d3d9.dll not loadable (error %lu)\n", GetLastError());
		return;
	}
	PFN_Direct3DCreate9 create = (PFN_Direct3DCreate9)GetProcAddress(lib, "Direct3DCreate9");
	IDirect3D9 *d3d = create ? create(D3D_SDK_VERSION) : nullptr;
	if (d3d == nullptr)
	{
		printf("D3D9: Direct3DCreate9 failed\n");
		return;
	}

	printf("D3D9: adapters=%u\n", d3d->GetAdapterCount());
	for (UINT i = 0; i < d3d->GetAdapterCount(); ++i)
	{
		D3DADAPTER_IDENTIFIER9 id;
		ZeroMemory(&id, sizeof(id));
		d3d->GetAdapterIdentifier(i, D3DENUM_WHQL_LEVEL, &id);
		D3DCAPS9 caps;
		ZeroMemory(&caps, sizeof(caps));
		HRESULT capsHr = d3d->GetDeviceCaps(i, D3DDEVTYPE_HAL, &caps);
		printf("D3D9 [%u] vendor=0x%04X device=0x%04X capsHr=0x%08lX desc=\"%s\" modes=%u\n",
			i, id.VendorId, id.DeviceId, (unsigned long)capsHr, id.Description,
			d3d->GetAdapterModeCount(i, D3DFMT_X8R8G8B8));
	}
	d3d->Release();
	FreeLibrary(lib);
}

int main()
{
	probe_d3d8();
	printf("\n");
	probe_d3d9();
	return 0;
}
