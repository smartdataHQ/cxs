# Grafana

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