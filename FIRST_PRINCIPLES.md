# First Principles and Directives

This document outlines the fundamental principles and directives that guide the design, development, and maintenance of the CXS platform. These principles are the foundation for all technical decisions and implementations.

## Core First Principles

### 1. **Simplicity Above All**
- **Principle:** Choose the simplest solution that meets requirements
- **Application:** Prefer standard container images over complex operators, use minimal configuration files, avoid unnecessary abstraction layers
- **Rationale:** Simpler systems are easier to understand, maintain, debug, and extend

### 2. **Developer Experience First**
- **Principle:** Optimize for the daily workflow of developers
- **Application:** "Super Simple Docker-Compose" approach, single command deployments, clear documentation, intuitive configuration
- **Rationale:** Productive developers deliver value faster and with higher quality

### 3. **Progressive Enhancement**
- **Principle:** Start simple and add complexity only when needed
- **Application:** Root-level deployment system that can grow with the platform, dev/staging/production environment scaling
- **Rationale:** Allows for rapid iteration and reduces initial complexity overhead

### 4. **Backwards Compatibility**
- **Principle:** Never break existing workflows or configurations
- **Application:** Individual service deployments continue to work alongside root-level orchestration
- **Rationale:** Enables gradual migration and reduces risk of adoption

### 5. **Declarative Infrastructure**
- **Principle:** Infrastructure and configuration should be declared, not scripted
- **Application:** GitOps with Rancher Fleet, Kubernetes manifests, Kustomize overlays
- **Rationale:** Ensures consistency, auditability, and reproducibility

## Technical Directives

### 1. **Version Management**
- **Directive:** Use latest stable versions in development, pinned versions in production
- **Implementation:** Container images use `latest` tag in dev, specific versions in production
- **Reference:** `docs/solution-version-policy.md`

### 2. **Configuration Management**
- **Directive:** Minimal root configuration with service-level customization
- **Implementation:** Root `.env` for service selection, individual service `.env.example` for customization
- **Reference:** `docs/root-deployment-system.md`

### 3. **Environment Consistency**
- **Directive:** Maintain consistent patterns across dev/staging/production
- **Implementation:** Kustomize overlays with environment-specific configurations
- **Reference:** `docs/migration-template.md`

### 4. **ARM64 Compatibility**
- **Directive:** Ensure all development tools work on Apple Silicon
- **Implementation:** Prefer standard, multi-arch container images over complex operators
- **Reference:** Historical migration from Percona to standard PostgreSQL

### 5. **Security by Design**
- **Directive:** No secrets in repository, external secret management
- **Implementation:** Rancher/Vault integration, ConfigMaps for non-sensitive defaults
- **Reference:** README security warnings

## Architectural Principles

### 1. **Single Source of Truth**
- **Principle:** One repository defines the desired state of all environments
- **Implementation:** GitOps with Rancher Fleet monitoring this repository
- **Reference:** Main README GitOps description

### 2. **Separation of Concerns**
- **Principle:** Separate application code from deployment configuration
- **Implementation:** Application code in separate repositories, deployment config in this repository
- **Reference:** README "Separate Code and Configuration" section

### 3. **Service Abstraction**
- **Principle:** Services should provide consistent interfaces regardless of implementation
- **Implementation:** Standard deployment scripts (`deploy-dev.sh`, `cleanup-dev.sh`, etc.)
- **Reference:** `docs/root-deployment-system.md`

### 4. **Documentation as Code**
- **Principle:** Documentation should be versioned, reviewed, and maintained like code
- **Implementation:** Markdown files in repository, clear structure, cross-references
- **Reference:** All documentation files in root and service directories

## Implementation Patterns

### 1. **Two-File Development**
- **Pattern:** Each service should be deployable with minimal setup
- **Implementation:** `.env.example` and `deploy-dev.sh` for each service
- **Reference:** `docs/migration-template.md`

### 2. **Cherry-Picking Services**
- **Pattern:** Developers should be able to select only the services they need
- **Implementation:** ENABLE_* flags in root `.env` file
- **Reference:** `docs/root-deployment-system.md`

### 3. **Resource Scaling**
- **Pattern:** Consistent resource allocation across environments
- **Implementation:** Dev (1 replica), Staging (2 replicas), Production (3+ replicas with limits)
- **Reference:** [MIGRATION_TEMPLATE.md](MIGRATION_TEMPLATE.md)

## Quality Standards

### 1. **Code Quality**
- **Standard:** YAML formatting, consistent naming, no hardcoded secrets
- **Implementation:** Review guidelines, automated checks where possible
- **Reference:** Project technical constraints

### 2. **Documentation Quality**
- **Standard:** Concise, accurate, focused on essential information
- **Implementation:** Minimal README structure, cross-referencing instead of duplication
- **Reference:** `docs/migration-template.md` documentation standards

### 3. **Testing and Validation**
- **Standard:** All configurations should be validated before deployment
- **Implementation:** Kustomize build validation, README examples testing
- **Reference:** Migration checklist

## Decision Framework

When making technical decisions, evaluate against these criteria:

1. **Does it simplify the developer experience?**
2. **Does it maintain backwards compatibility?**
3. **Does it follow established patterns?**
4. **Does it improve system reliability?**
5. **Does it reduce maintenance overhead?**

If a decision conflicts with these principles, it should be carefully justified and documented.