# Kafka SASL Authentication Setup

This configures SASL/PLAIN authentication for the external Kafka cluster on data layer machines.

## Quick Start

### 1. Configure Environment Variables
```bash
# Copy example environment file
cp .env.example .env

# Edit .env with actual passwords (this file is in .gitignore)
nano .env
```

### 2. Enable Authentication (3-Phase Approach)
```bash
# Load environment variables
source .env

# Test connectivity first
ansible data_nodes -m ping

# Phase 1: Deploy SASL configuration
ansible-playbook -i inventories/data-layer.ini playbooks/kafka-sasl-phase1-config.yml

# Phase 2: Verify configuration
ansible-playbook -i inventories/data-layer.ini playbooks/kafka-sasl-phase2-verify.yml

# Phase 3: Restart services and test
ansible-playbook -i inventories/data-layer.ini playbooks/kafka-sasl-phase3-restart.yml
```

## Authentication Details

### User Accounts Created
- **admin**: Full administrative access (super user)
- **service**: For application services (producer/consumer)  
- **client**: For client applications

### Security Configuration
- **Protocol**: SASL_PLAINTEXT
- **Mechanism**: PLAIN
- **Authorization**: ACLs enabled (deny by default)
- **Super Users**: admin user has full access

### Configuration Files
- **JAAS Config**: `/home/kafka/kafka/config/kafka_server_jaas.conf`
- **Admin Client**: `/home/kafka/kafka/config/admin.properties`
- **Service Client**: `/home/kafka/kafka/config/client.properties`

## Client Connection Examples

### Admin Operations
```bash
# List topics as admin
kafka-topics.sh \
  --bootstrap-server c001db1:9092,c001db2:9092,c001db3:9092 \
  --command-config /home/kafka/kafka/config/admin.properties \
  --list
```

### Application Connection (Java)
```properties
bootstrap.servers=c001db1:9092,c001db2:9092,c001db3:9092
security.protocol=SASL_PLAINTEXT
sasl.mechanism=PLAIN
sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required \
    username="service" \
    password="Svc-K4fka-P4ss!";
```

### Kubernetes Integration
Update your application ConfigMaps:
```yaml
KAFKA_BOOTSTRAP_SERVERS: "c001db1:9092,c001db2:9092,c001db3:9092"
KAFKA_SECURITY_PROTOCOL: "SASL_PLAINTEXT"
KAFKA_SASL_MECHANISM: "PLAIN"
KAFKA_SASL_USERNAME: "service"
# KAFKA_SASL_PASSWORD: stored in Secret
```

## ACL Management

### Grant Access to Applications
```bash
# Allow service user to produce/consume all topics
kafka-acls.sh \
  --bootstrap-server c001db1:9092 \
  --command-config /home/kafka/kafka/config/admin.properties \
  --add \
  --allow-principal User:service \
  --operation All \
  --topic '*' \
  --group '*'
```

### List Current ACLs
```bash
kafka-acls.sh \
  --bootstrap-server c001db1:9092 \
  --command-config /home/kafka/kafka/config/admin.properties \
  --list
```

## Security Best Practices

### Password Management
1. **Change default passwords** in `group_vars/data_nodes.yml`
2. **Use Ansible Vault** for production: `ansible-vault encrypt group_vars/data_nodes.yml`
3. **Rotate passwords** regularly
4. **Use different passwords** per environment

### Network Security
1. **Firewall rules**: Restrict port 9092 to known clients only
2. **VPN/Private networks**: Use Tailscale or similar for access
3. **SSL/TLS**: Consider upgrading to SASL_SSL for production

### Access Control
1. **Principle of least privilege**: Grant minimal required permissions
2. **Separate service accounts**: Different users for different applications
3. **Regular audit**: Review ACLs and user access periodically

## Troubleshooting

### Authentication Failures
```bash
# Check JAAS configuration
cat /home/kafka/kafka/config/kafka_server_jaas.conf

# Check server logs
journalctl -u kafka -f

# Test with debug logging
export KAFKA_OPTS="-Djava.security.debug=all"
```

### Common Issues
1. **Wrong credentials**: Verify username/password in client config
2. **Network connectivity**: Ensure port 9092 is accessible
3. **ACL denied**: Check permissions with `kafka-acls.sh --list`
4. **Service restart needed**: Restart Kafka after config changes

## Rollback Procedure

If authentication causes issues:
```bash
# 1. Stop Kafka on all nodes
ansible data_nodes -m systemd -a "name=kafka state=stopped"

# 2. Restore original configuration
ansible data_nodes -m shell -a "cp /home/kafka/kafka/config/kraft/server.properties.backup-* /home/kafka/kafka/config/kraft/server.properties"

# 3. Remove JAAS config from systemd
ansible data_nodes -m lineinfile -a "path=/etc/systemd/system/kafka.service regexp='^Environment=\"KAFKA_OPTS=' state=absent"

# 4. Reload and restart
ansible data_nodes -m systemd -a "daemon_reload=yes"
ansible data_nodes -m systemd -a "name=kafka state=started"
```

## Next Steps

1. **Test authentication** with sample applications
2. **Update KafkaUI** configuration with SASL credentials
3. **Migrate inbox service** to use authenticated cluster
4. **Implement monitoring** for authentication metrics
5. **Document ACL policies** for each application