using UnityEngine;

public class Hover : MonoBehaviour
{
    public float speed;
    public float acceleration;

    void Update()
    {
        if (speed < 1.5f)
        {
            speed += acceleration * Time.deltaTime;
        }
        transform.position = new Vector3(transform.position.x, transform.position.y, transform.position.z + speed);
        transform.rotation = Quaternion.Euler(Mathf.Sin(Time.realtimeSinceStartup*2)*10-90, -90, 90);
    }
}
