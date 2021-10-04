using UnityEngine;

[RequireComponent(typeof(Camera))]
[AddComponentMenu("Camera/Follow Player")]

public class followPlayer : MonoBehaviour
{
    [SerializeField] private Transform playerTransform;
    [SerializeField] private float smoothness = 0.5f;

    private void Update()
    {
        transform.position = Vector3.Lerp(transform.position, new Vector3(playerTransform.position.x, transform.position.y, playerTransform.position.z), smoothness * Time.deltaTime);
    }
}
