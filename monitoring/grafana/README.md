# Grafana

## Grafana Authorization via Microsoft Entra ID

Grafana roles (Admin, Editor, Viewer) are assigned based on **App Roles** configured in **Microsoft Entra ID** (formerly Azure AD). These roles are synchronized automatically and cannot be edited directly in Grafana.

### How to Assign Roles

To assign a user to a Grafana role:

1. Go to **Azure Portal**  
   [Enterprise Applications – grafana-contextsuite-com](https://portal.azure.com/#view/Microsoft_AAD_IAM/ManagedAppMenuBlade/~/Users/objectId/71f38d11-d711-460a-a37f-d244f5edda97/appId/91993a9f-e1bc-44bc-8487-2f80f8c503fd/)

2. In the left sidebar, click **Users and groups**

3. Click **Add user/group**

4. Select the user

5. Under **Select a role**, choose one of:
    - `Grafana Admin`
    - `Grafana Editor`
    - `Grafana Viewer` (default if no role is assigned)

6. Save

The user will receive the corresponding Grafana role on next login.

> Note: These roles are enforced via the OIDC claims passed to Grafana. Manual role assignment inside Grafana UI will not work and will show a message:
>
> _"This user's role is not editable because it is synchronized from your auth provider."_

### Role Sync Notes

- Changes take effect on next login
- Group claims must be included in the OIDC token — make sure the application is configured to emit them

## Grafana DB Password
The database password is managed by the percona postgresql operator and kept in
a generated secret file. To update it you need to run the following command:

After enabling credentials towards the kubernetes cluster:

```bash
./update-db-secret.sh
```

## Grafana Alert Rules 

Alert rules should ideally be delivered via Grafana's provisioning system. 
This has 3 configuration points:

### 1. **Alert Rule Definition**: 
   - Alert rules are defined in YAML files located in the [./alerting](./alerting/) directory
   - It is easiest to author the rules in the Grafana UI and then to export them as YAML and place them in the [./alerting](./alerting/) directory.
   - **NOTE**: When exporting from the UI, the `groups[].rules[].for` field is sometimes missing.
               In that case, this field myst be added to the YAML manually (e.g. `for: "15m"`), otherwise grafana will silently fail provisoining the Alert Rule

### 2. **Package Alert Rule YAML into a ConfigMap via Kustomize**:
   - The [alerting/kustomization.ayml](alerting/kustomization.yaml) file defines how these rule files are rendered as ConfigMaps.

### 3. **Mount ConfigMap into Grafana Pod via `values.yaml`**:
   - The [values.yaml](./values.yaml) file for Grafana is used to mount the Alert rule ConfigMaps into the Grafana pod via the `extraConfigmapMounts` directive. 
   - Example configuration:
     ```yaml
     extraConfigmapMounts:
       - name: grafana-longhorn-alerts
         mountPath: /etc/grafana/provisioning/alerting/longhorn-rules.yaml
         subPath: longhorn-rules.yaml
         configMap: grafana-longhorn-alerts
         readOnly: true
     ```

### 4. Commit and push