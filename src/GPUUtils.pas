unit GPUUtils;

{
  GPU Utils

  Copyright (c) 2026 Felipe Daragon
  License: MIT
  See https://github.com/DaragonTech/llama-cpp-delphi for details
}

interface

uses
  Winapi.Windows,
  System.SysUtils,
  System.IOUtils,
  CatUtils;

function HasCudaGPU(const ALibDir: string): Boolean;
function HasVulkanGPU: Boolean;
function GetVulkanGPUName: string;

implementation

type
  TGetCudaDeviceCount = function: Integer; cdecl;

type
  TVkResult = Integer;
  TVkInstance = Pointer;
  TVkPhysicalDevice = Pointer;

  PVkInstanceCreateInfo = ^TVkInstanceCreateInfo;
  TVkInstanceCreateInfo = record
    sType: Integer;
    pNext: Pointer;
    flags: Cardinal;
    pApplicationInfo: Pointer;
    enabledLayerCount: Cardinal;
    ppEnabledLayerNames: Pointer;
    enabledExtensionCount: Cardinal;
    ppEnabledExtensionNames: Pointer;
  end;

  TVkPhysicalDevicePropertiesHead = record
    apiVersion: Cardinal;
    driverVersion: Cardinal;
    vendorID: Cardinal;
    deviceID: Cardinal;
    deviceType: Integer;
    deviceName: array[0..255] of AnsiChar;
    pipelineCacheUUID: array[0..15] of Byte;
  end;

  PVkPhysicalDevicePropertiesHead =
    ^TVkPhysicalDevicePropertiesHead;

  TvkCreateInstance = function(
    const pCreateInfo: PVkInstanceCreateInfo;
    pAllocator: Pointer;
    var pInstance: TVkInstance
  ): TVkResult; stdcall;

  TvkDestroyInstance = procedure(
    Instance: TVkInstance;
    pAllocator: Pointer
  ); stdcall;

  TvkEnumeratePhysicalDevices = function(
    Instance: TVkInstance;
    var pPhysicalDeviceCount: Cardinal;
    pPhysicalDevices: Pointer
  ): TVkResult; stdcall;

  TvkGetPhysicalDeviceProperties = procedure(
    PhysicalDevice: TVkPhysicalDevice;
    pProperties: Pointer
  ); stdcall;

const
  VK_SUCCESS = 0;
  VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO = 1;


function HasVulkanGPU: Boolean;
var
  H: HMODULE;
  vkCreateInstance: TvkCreateInstance;
  vkDestroyInstance: TvkDestroyInstance;
  vkEnumeratePhysicalDevices: TvkEnumeratePhysicalDevices;

  CreateInfo: TVkInstanceCreateInfo;
  Instance: TVkInstance;
  DeviceCount: Cardinal;
  Res: TVkResult;
begin
  Result := False;

  H := LoadLibrary('vulkan-1.dll');

  if H = 0 then
    Exit;

  try
    vkCreateInstance := TvkCreateInstance(
      GetProcAddress(H, 'vkCreateInstance')
    );

    vkDestroyInstance := TvkDestroyInstance(
      GetProcAddress(H, 'vkDestroyInstance')
    );

    vkEnumeratePhysicalDevices := TvkEnumeratePhysicalDevices(
      GetProcAddress(H, 'vkEnumeratePhysicalDevices')
    );

    if not Assigned(vkCreateInstance) or
       not Assigned(vkDestroyInstance) or
       not Assigned(vkEnumeratePhysicalDevices) then
      Exit;

    FillChar(
      CreateInfo,
      SizeOf(CreateInfo),
      0
    );

    CreateInfo.sType :=
      VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO;

    Instance := nil;

    Res := vkCreateInstance(
      @CreateInfo,
      nil,
      Instance
    );

    if Res <> VK_SUCCESS then
      Exit;

    try
      DeviceCount := 0;

      Res := vkEnumeratePhysicalDevices(
        Instance,
        DeviceCount,
        nil
      );

      if Res = VK_SUCCESS then
        Result := DeviceCount > 0;

    finally
      vkDestroyInstance(
        Instance,
        nil
      );
    end;

  finally
    FreeLibrary(H);
  end;
end;


function GetVulkanGPUName: string;
var
  H: HMODULE;

  vkCreateInstance: TvkCreateInstance;
  vkDestroyInstance: TvkDestroyInstance;
  vkEnumeratePhysicalDevices: TvkEnumeratePhysicalDevices;
  vkGetPhysicalDeviceProperties: TvkGetPhysicalDeviceProperties;

  CreateInfo: TVkInstanceCreateInfo;
  Instance: TVkInstance;

  DeviceCount: Cardinal;
  Devices: array of TVkPhysicalDevice;

  PropertiesBuffer: array[0..4095] of Byte;
  Props: PVkPhysicalDevicePropertiesHead;

  Res: TVkResult;
begin
  Result := '';

  H := LoadLibrary('vulkan-1.dll');

  if H = 0 then
    Exit;

  try
    vkCreateInstance := TvkCreateInstance(
      GetProcAddress(H, 'vkCreateInstance')
    );

    vkDestroyInstance := TvkDestroyInstance(
      GetProcAddress(H, 'vkDestroyInstance')
    );

    vkEnumeratePhysicalDevices := TvkEnumeratePhysicalDevices(
      GetProcAddress(H, 'vkEnumeratePhysicalDevices')
    );

    vkGetPhysicalDeviceProperties :=
      TvkGetPhysicalDeviceProperties(
        GetProcAddress(
          H,
          'vkGetPhysicalDeviceProperties'
        )
      );

    if not Assigned(vkCreateInstance) or
       not Assigned(vkDestroyInstance) or
       not Assigned(vkEnumeratePhysicalDevices) or
       not Assigned(vkGetPhysicalDeviceProperties) then
      Exit;

    FillChar(
      CreateInfo,
      SizeOf(CreateInfo),
      0
    );

    CreateInfo.sType :=
      VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO;

    Instance := nil;

    Res := vkCreateInstance(
      @CreateInfo,
      nil,
      Instance
    );

    if Res <> VK_SUCCESS then
      Exit;

    try
      DeviceCount := 0;

      Res := vkEnumeratePhysicalDevices(
        Instance,
        DeviceCount,
        nil
      );

      if (Res <> VK_SUCCESS) or
         (DeviceCount = 0) then
        Exit;

      SetLength(
        Devices,
        DeviceCount
      );

      Res := vkEnumeratePhysicalDevices(
        Instance,
        DeviceCount,
        @Devices[0]
      );

      if Res <> VK_SUCCESS then
        Exit;

      FillChar(
        PropertiesBuffer,
        SizeOf(PropertiesBuffer),
        0
      );

      vkGetPhysicalDeviceProperties(
        Devices[0],
        @PropertiesBuffer[0]
      );

      Props :=
        PVkPhysicalDevicePropertiesHead(
          @PropertiesBuffer[0]
        );

      Result :=
        string(
          AnsiString(
            PAnsiChar(
              @Props^.deviceName[0]
            )
          )
        );

    finally
      vkDestroyInstance(
        Instance,
        nil
      );
    end;

  finally
    FreeLibrary(H);
  end;
end;


function HasCudaGPU(const ALibDir: string): Boolean;
var
  H: HMODULE;
  GetCudaDeviceCount: TGetCudaDeviceCount;
  ProcPtr: Pointer;
  DllPath: string;
begin
  Result := False;

  DllPath :=
    TPath.Combine(
      ALibDir,
      'ggml-cuda.dll'
    );

  if not FileExists(DllPath) then
    Exit;

  H := LoadLibrary(
    PChar(DllPath)
  );

  if H = 0 then
    Exit;

  try
    ProcPtr :=
      GetProcAddress(
        H,
        'ggml_backend_cuda_get_device_count'
      );

    if not Assigned(ProcPtr) then
      Exit;

    GetCudaDeviceCount :=
      TGetCudaDeviceCount(
        ProcPtr
      );

    try
      Result :=
        GetCudaDeviceCount() > 0;

    except
      Result := False;
    end;

  finally
    FreeLibrary(H);
  end;
end;


// ------------------------------------------------------------------------//

end.
