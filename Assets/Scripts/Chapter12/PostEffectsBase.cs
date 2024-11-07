using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteInEditMode]
[RequireComponent(typeof(Camera))]
public class PostEffectsBase : MonoBehaviour
{
    // Start is called before the first frame update
    protected void Start()
    {
        CheckResources();
    }

    // Update is called once per frame
    void Update()
    {
        
    }
    protected void CheckResources()
    {
        bool isSupported = CheckSupport();

        if (isSupported == false)
        {
            NotSupported();
        }
    }
    protected bool CheckSupport()
    {
        if (SystemInfo.supportsImageEffects == false || SystemInfo.supportsRenderTextures == false)
        {
            Debug.LogWarning("This platform does not support image effects or render textures");
            return false;
        }
        return true;
    }
    protected void NotSupported()
    {
        enabled = false;
    }
    /// <summary>
    /// 
    /// </summary>
    /// <param name="shader">特效需要的shader</param>
    /// <param name="material">用于后期处理的材质</param>
    /// <returns></returns>
    protected Material CheckShaderAndCretaeMaterial(Shader shader, Material material)
    {
        if (shader == null)
        {
            return null;
        }
        if (shader.isSupported && material && material.shader == shader)
        {
            return material;
        }
        if (!shader.isSupported)
        {
            return null;
        }
        else
        {
            material = new Material(shader);
            material.hideFlags = HideFlags.DontSave;
            if (material)
            {
                return material;
            }
            else
            {
                return null;
            }
        }
    }
}
