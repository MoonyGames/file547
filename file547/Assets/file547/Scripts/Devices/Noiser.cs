using UnityEngine;
using System.Collections;

public class Noiser : MonoBehaviour
{
    private IndieMarc.EnemyVision.Enemy enemy;
    private IndieMarc.EnemyVision.VisionTarget visionTarget;

    private BoxCollider collider;
    private bool triggerActivated = true;

    private void Start()
    {
        collider = GetComponent<BoxCollider>();
        visionTarget = GetComponent<IndieMarc.EnemyVision.VisionTarget>();
    }

    public void distract()
    {
        triggerActivated = triggerActivated == true ? false : true;

        collider.enabled = triggerActivated;
        visionTarget.visible = triggerActivated;
    }

    private void OnTriggerEnter(Collider other)
    {
        if(other.tag == "Enemy")
        {
            if(other.GetComponent<IndieMarc.EnemyVision.Enemy>() != null)
            {
                enemy = other.GetComponent<IndieMarc.EnemyVision.Enemy>();
            }
            else if (other.GetComponentInParent<IndieMarc.EnemyVision.Enemy>() != null)
            {
                enemy = other.GetComponentInParent<IndieMarc.EnemyVision.Enemy>();
            }

            StartCoroutine(distract(5f));
        }
    }

    private IEnumerator distract(float time)
    {
        enemy.follow_target = gameObject;

        yield return new WaitForSeconds(0.25f);

        enemy.ChangeState(IndieMarc.EnemyVision.EnemyState.Alert);

        yield return new WaitForSeconds(time);

        enemy.follow_target = null;
        enemy.ChangeState(IndieMarc.EnemyVision.EnemyState.Patrol);
        collider.enabled = false;
    }
}
