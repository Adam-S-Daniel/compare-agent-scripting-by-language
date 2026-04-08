Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Mock secret configuration data for testing and demonstration.
# Each secret has: Name, LastRotated date, PolicyDays, RequiredBy services.

function Get-MockSecrets {
    <#
    .SYNOPSIS
        Returns a set of mock secrets with varying rotation states.
    #>
    [CmdletBinding()]
    [OutputType([hashtable[]])]
    param()

    return [hashtable[]]@(
        @{
            Name        = [string]'database-root-password'
            LastRotated = [datetime]'2025-12-15'
            PolicyDays  = [int]90
            RequiredBy  = [string[]]@('api-server', 'batch-worker', 'analytics-pipeline')
        }
        @{
            Name        = [string]'stripe-api-key'
            LastRotated = [datetime]'2026-03-20'
            PolicyDays  = [int]30
            RequiredBy  = [string[]]@('payment-service', 'billing-service')
        }
        @{
            Name        = [string]'jwt-signing-key'
            LastRotated = [datetime]'2026-01-05'
            PolicyDays  = [int]60
            RequiredBy  = [string[]]@('auth-service', 'api-gateway')
        }
        @{
            Name        = [string]'tls-certificate'
            LastRotated = [datetime]'2026-02-01'
            PolicyDays  = [int]365
            RequiredBy  = [string[]]@('load-balancer', 'cdn')
        }
        @{
            Name        = [string]'aws-iam-access-key'
            LastRotated = [datetime]'2026-03-30'
            PolicyDays  = [int]14
            RequiredBy  = [string[]]@('deploy-pipeline', 's3-backup-job')
        }
        @{
            Name        = [string]'redis-auth-token'
            LastRotated = [datetime]'2026-02-10'
            PolicyDays  = [int]45
            RequiredBy  = [string[]]@('cache-layer', 'session-store')
        }
        @{
            Name        = [string]'slack-webhook-secret'
            LastRotated = [datetime]'2026-03-01'
            PolicyDays  = [int]180
            RequiredBy  = [string[]]@('notification-service')
        }
        @{
            Name        = [string]'datadog-api-key'
            LastRotated = [datetime]'2025-11-01'
            PolicyDays  = [int]90
            RequiredBy  = [string[]]@('monitoring-agent', 'log-shipper', 'apm-collector')
        }
    )
}
