namespace UnityEngine.Rendering.Universal
{
    public class MobileMotionBlurUrp : ScriptableRendererFeature
    {
        public enum SampleType
        {
            Six = 6,
            Eight = 8,
            Ten = 10
        };

        [System.Serializable]
        public class MobileCameraMotionBlurSettings
        {
            public RenderPassEvent Event = RenderPassEvent.AfterRenderingTransparents;

            [Range(0, 1)]
            public float Distance;

            [Range(1, 4)]
            public int FastFilter = 4;

            public SampleType SampleCount = SampleType.Six;

            public Material blitMaterial = null;
        }

        public MobileCameraMotionBlurSettings settings = new MobileCameraMotionBlurSettings();

        MobileMotionBlurUrpPass mobileMotionBlurLwrpPass;

        public override void Create()
        {
            mobileMotionBlurLwrpPass = new MobileMotionBlurUrpPass(settings.Event, settings.blitMaterial, settings.Distance, settings.FastFilter, (int)settings.SampleCount, this.name);
        }

        public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
        {
            mobileMotionBlurLwrpPass.Setup(renderer.cameraColorTarget, renderingData.cameraData.camera.projectionMatrix, renderingData.cameraData.camera.worldToCameraMatrix);
            renderer.EnqueuePass(mobileMotionBlurLwrpPass);
        }
    }

    public class MobileMotionBlurUrpPass : ScriptableRenderPass
    {
        private Material material;

        static readonly int currentPrevString = Shader.PropertyToID("_CurrentToPreviousViewProjectionMatrix");
        static readonly int distanceString = Shader.PropertyToID("_Distance");
        static readonly int blurTexString = Shader.PropertyToID("_BlurTex");
        static readonly int tempCopyString = Shader.PropertyToID("_TempCopy");
        static readonly string eightFeature = "EIGHT";
        static readonly string tenFeature = "TEN";

        private readonly string tag;
        private readonly float distance;
        private readonly int fastFilter;
        private readonly int sampleCount;

        private CommandBuffer cmd;

        private Matrix4x4 projectionMatrix, worldToCameraMatrix, previousViewProjection, viewProj, currentToPreviousViewProjectionMatrix;

        private RenderTargetIdentifier source;
        private RenderTargetIdentifier blurTex = new RenderTargetIdentifier(blurTexString);
        private RenderTargetIdentifier tempCopy = new RenderTargetIdentifier(tempCopyString);

        public MobileMotionBlurUrpPass(RenderPassEvent renderPassEvent, Material material,
            float distance, int fastFilter, int sampleCount, string tag)
        {
            this.renderPassEvent = renderPassEvent;
            this.tag = tag;
            this.material = material;
            this.sampleCount = sampleCount;

            this.distance = distance;
            this.fastFilter = fastFilter;
        }


        public void Setup(RenderTargetIdentifier source, Matrix4x4 projectionMatrix, Matrix4x4 worldToCameraMatrix)
        {
            this.source = source;
            this.projectionMatrix = projectionMatrix;
            this.worldToCameraMatrix = worldToCameraMatrix;
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            CommandBuffer cmd = CommandBufferPool.Get(tag);
            RenderTextureDescriptor opaqueDesc = renderingData.cameraData.cameraTargetDescriptor;
            opaqueDesc.depthBufferBits = 0;

            cmd.GetTemporaryRT(tempCopyString, opaqueDesc, FilterMode.Bilinear);
            cmd.CopyTexture(source, tempCopy);

            switch (sampleCount)
            {
                case 6:
                    material.DisableKeyword(eightFeature);
                    material.DisableKeyword(tenFeature);
                    break;
                case 8:
                    material.EnableKeyword(eightFeature);
                    material.DisableKeyword(tenFeature);
                    break;
                case 10:
                    material.EnableKeyword(eightFeature);
                    material.EnableKeyword(tenFeature);
                    break;
            }

            viewProj = projectionMatrix * worldToCameraMatrix;

            if (previousViewProjection == Matrix4x4.zero)
            {
                previousViewProjection = viewProj;
            }

            if (viewProj == previousViewProjection)
            {
                cmd.Blit(tempCopy, source);
                context.ExecuteCommandBuffer(cmd);
                CommandBufferPool.Release(cmd);
                return;
            }

            currentToPreviousViewProjectionMatrix = previousViewProjection * viewProj.inverse;
            material.SetMatrix(currentPrevString, currentToPreviousViewProjectionMatrix);
            material.SetFloat(distanceString, 1 - distance);
            previousViewProjection = viewProj;

            cmd.GetTemporaryRT(blurTexString, Screen.width / fastFilter, Screen.height / fastFilter, 0, FilterMode.Bilinear);
            cmd.Blit(tempCopy, blurTex, material, 0);
            cmd.Blit(tempCopy, source, material, 1);

            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }

        public override void FrameCleanup(CommandBuffer cmd)
        {
            cmd.ReleaseTemporaryRT(tempCopyString);
            cmd.ReleaseTemporaryRT(blurTexString);
        }
    }
}
