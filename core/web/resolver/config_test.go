package resolver

import (
	"testing"

	"go.uber.org/zap/zapcore"
	"gopkg.in/guregu/null.v4"

	"github.com/smartcontractkit/chainlink/core/config"
	"github.com/smartcontractkit/chainlink/core/internal/testutils/configtest"
)

func TestResolver_Config(t *testing.T) {
	t.Parallel()

	query := `
		query GetConfiguration {
			config {
				items {
					key
					value
				}
			}
		}`

	testCases := []GQLTestCase{
		unauthorizedTestCase(GQLTestCase{query: query}, "config"),
		{
			name:          "success",
			authenticated: true,
			before: func(f *gqlTestFramework) {
				// Using the default config value for now just to validate that it works
				// Mocking this would require complying to the whole interface
				// Which means mocking each method here, which I'm not sure we would like to do
				cfg := configtest.NewTestGeneralConfigWithOverrides(t, configtest.GeneralConfigOverrides{
					AdminCredentialsFile: null.StringFrom("test"),
					AdvisoryLockID:       null.IntFrom(1),
					AllowOrigins:         null.StringFrom("test"),
					BlockBackfillDepth:   null.IntFrom(1),
					BlockBackfillSkip:    null.BoolFrom(false),
					ClientNodeURL:        null.StringFrom("test"),
					DatabaseURL:          null.StringFrom("test"),
					DefaultChainID:       nil,
					DefaultHTTPAllowUnrestrictedNetworkAccess: null.BoolFrom(true),
					DefaultHTTPTimeout:                        nil,
					DefaultMaxHTTPAttempts:                    null.IntFrom(1),
					Dev:                                       null.BoolFrom(true),
					Dialect:                                   "",
					EVMDisabled:                               null.BoolFrom(true),
					EthereumDisabled:                          null.BoolFrom(true),
					EthereumURL:                               null.StringFrom(""),
					FeatureExternalInitiators:                 null.BoolFrom(true),
					GlobalBalanceMonitorEnabled:               null.BoolFrom(true),
					GlobalChainType:                           null.StringFrom(""),
					GlobalEthTxReaperThreshold:                nil,
					GlobalEthTxResendAfterThreshold:           nil,
					GlobalEvmEIP1559DynamicFees:               null.BoolFrom(true),
					GlobalEvmFinalityDepth:                    null.IntFrom(1),
					GlobalEvmGasBumpPercent:                   null.IntFrom(1),
					GlobalEvmGasBumpTxDepth:                   null.IntFrom(1),
					GlobalEvmGasBumpWei:                       nil,
					GlobalEvmGasLimitDefault:                  null.IntFrom(1),
					GlobalEvmGasLimitMultiplier:               null.FloatFrom(1),
					GlobalEvmGasPriceDefault:                  nil,
					GlobalEvmGasTipCapDefault:                 nil,
					GlobalEvmGasTipCapMinimum:                 nil,
					GlobalEvmHeadTrackerHistoryDepth:          null.IntFrom(1),
					GlobalEvmHeadTrackerMaxBufferSize:         null.IntFrom(1),
					GlobalEvmHeadTrackerSamplingInterval:      nil,
					GlobalEvmLogBackfillBatchSize:             null.IntFrom(1),
					GlobalEvmMaxGasPriceWei:                   nil,
					GlobalEvmMinGasPriceWei:                   nil,
					GlobalEvmNonceAutoSync:                    null.BoolFrom(false),
					GlobalEvmRPCDefaultBatchSize:              null.IntFrom(1),
					GlobalFlagsContractAddress:                null.StringFrom("test"),
					GlobalGasEstimatorMode:                    null.StringFrom("test"),
					GlobalMinIncomingConfirmations:            null.IntFrom(1),
					GlobalMinRequiredOutgoingConfirmations:    null.IntFrom(1),
					GlobalMinimumContractPayment:              nil,
					KeeperMaximumGracePeriod:                  null.IntFrom(1),
					KeeperRegistrySyncInterval:                nil,
					KeeperRegistrySyncUpkeepQueueSize:         null.IntFrom(1),
					LogLevel:                                  &config.LogLevel{Level: zapcore.ErrorLevel},
					DefaultLogLevel:                           nil,
					LogSQL:                                    null.BoolFrom(true),
					LogToDisk:                                 null.BoolFrom(true),
					OCRKeyBundleID:                            null.StringFrom("test"),
					OCRObservationTimeout:                     nil,
					OCRTransmitterAddress:                     nil,
					P2PBootstrapPeers:                         nil,
					P2PListenPort:                             null.IntFrom(1),
					P2PPeerID:                                 "",
					P2PPeerIDError:                            nil,
					SecretGenerator:                           nil,
					TriggerFallbackDBPollInterval:             nil,
				})
				cfg.SetRootDir("/tmp/chainlink_test/gql-test")

				f.App.On("GetConfig").Return(cfg)
			},
			query: query,
			result: `{
				"config": {
					"items": [
					{"value":"1s", "key":"ADVISORY_LOCK_CHECK_INTERVAL"},
					{"value":"1027321974924625846","key":"ADVISORY_LOCK_ID"},
					{
						"value": "test",
						"key": "ALLOW_ORIGINS"
					}, {
						"value": "1",
						"key": "BLOCK_BACKFILL_DEPTH"
					}, {
						"value": "0",
						"key": "BLOCK_HISTORY_ESTIMATOR_BLOCK_DELAY"
					}, {
						"value": "0",
						"key": "BLOCK_HISTORY_ESTIMATOR_BLOCK_HISTORY_SIZE"
					}, {
						"value": "0",
						"key": "BLOCK_HISTORY_ESTIMATOR_TRANSACTION_PERCENTILE"
					}, {
						"value": "http://localhost:6688",
						"key": "BRIDGE_RESPONSE_URL"
					}, {
						"value": "",
						"key": "CHAIN_TYPE"
					}, {
						"value": "test",
						"key": "CLIENT_NODE_URL"
					}, {
						"value": "1h0m0s",
						"key": "DATABASE_BACKUP_FREQUENCY"
					}, {
						"value": "none",
						"key": "DATABASE_BACKUP_MODE"
					}, {
						"value": "none",
						"key": "DATABASE_LOCKING_MODE"
					}, {
						"value": "0",
						"key": "ETH_CHAIN_ID"
					}, {
						"value": "32768",
						"key": "DEFAULT_HTTP_LIMIT"
					}, {
						"value": "15s",
						"key": "DEFAULT_HTTP_TIMEOUT"
					}, {
						"value": "true",
						"key": "CHAINLINK_DEV"
					}, {
						"value": "true",
						"key": "ETH_DISABLED"
					}, {
						"value": "",
						"key": "ETH_HTTP_URL"
					}, {
						"value": "[]",
						"key": "ETH_SECONDARY_URLS"
					}, {
						"value": "",
						"key": "ETH_URL"
					}, {
						"value": "",
						"key": "EXPLORER_URL"
					}, {
						"value": "1",
						"key": "FM_DEFAULT_TRANSACTION_QUEUE_DEPTH"
					}, {
						"value": "true",
						"key": "FEATURE_EXTERNAL_INITIATORS"
					}, {
						"value": "false",
						"key": "FEATURE_OFFCHAIN_REPORTING"
					}, {
						"value": "",
						"key": "GAS_ESTIMATOR_MODE"
					}, {
						"value": "true",
						"key": "INSECURE_FAST_SCRYPT"
					}, {
						"value": "false",
						"key": "JSON_CONSOLE"
					}, {
						"value": "1h0m0s",
						"key": "JOB_PIPELINE_REAPER_INTERVAL"
					}, {
						"value": "24h0m0s",
						"key": "JOB_PIPELINE_REAPER_THRESHOLD"
					}, {
						"value": "1",
						"key": "KEEPER_DEFAULT_TRANSACTION_QUEUE_DEPTH"
					}, {
						"value": "20",
						"key": "KEEPER_GAS_PRICE_BUFFER_PERCENT"
					}, {
						"value": "20",
						"key": "KEEPER_GAS_TIP_CAP_BUFFER_PERCENT"
					}, {
						"value": "0",
						"key": "KEEPER_MAXIMUM_GRACE_PERIOD"
					}, {
						"value": "0",
						"key": "KEEPER_REGISTRY_CHECK_GAS_OVERHEAD"
					}, {
						"value": "0",
						"key": "KEEPER_REGISTRY_PERFORM_GAS_OVERHEAD"
					}, {
						"value": "0",
						"key": "KEEPER_REGISTRY_SYNC_UPKEEP_QUEUE_SIZE"
					}, {
						"value": "30s",
						"key": "LEASE_LOCK_DURATION"
					}, {
						"value": "1s",
						"key": "LEASE_LOCK_REFRESH_INTERVAL"
					}, {
						"value": "",
						"key": "LINK_CONTRACT_ADDRESS"
					}, {
						"value": "",
						"key": "FLAGS_CONTRACT_ADDRESS"
					}, {
						"value": "error",
						"key": "LOG_LEVEL"
					}, {
						"value": "false",
						"key": "LOG_SQL_MIGRATIONS"
					}, {
						"value": "true",
						"key": "LOG_SQL"
					}, {
						"value": "true",
						"key": "LOG_TO_DISK"
					}, {
						"value": "30s",
						"key": "TRIGGER_FALLBACK_DB_POLL_INTERVAL"
					}, {
						"value": "1",
						"key": "OCR_DEFAULT_TRANSACTION_QUEUE_DEPTH"
					}, {
						"value": "false",
						"key": "OCR_TRACE_LOGGING"
					}, {
						"value": "V1",
						"key": "P2P_NETWORKING_STACK"
					}, {
						"value": "",
						"key": "P2P_PEER_ID"
					}, {
						"value": "10",
						"key": "P2P_INCOMING_MESSAGE_BUFFER_SIZE"
					}, {
						"value": "10",
						"key": "P2P_OUTGOING_MESSAGE_BUFFER_SIZE"
					}, {
						"value": "[]",
						"key": "P2P_BOOTSTRAP_PEERS"
					}, {
						"value": "0.0.0.0",
						"key": "P2P_LISTEN_IP"
					}, {
						"value": "",
						"key": "P2P_LISTEN_PORT"
					}, {
						"value": "10s",
						"key": "P2P_NEW_STREAM_TIMEOUT"
					}, {
						"value": "10",
						"key": "P2P_DHT_LOOKUP_INTERVAL"
					}, {
						"value": "20s",
						"key": "P2P_BOOTSTRAP_CHECK_INTERVAL"
					}, {
						"value": "[]",
						"key": "P2PV2_ANNOUNCE_ADDRESSES"
					}, {
						"value": "[]",
						"key": "P2PV2_BOOTSTRAPPERS"
					}, {
						"value": "15s",
						"key": "P2PV2_DELTA_DIAL"
					}, {
						"value": "1m0s",
						"key": "P2PV2_DELTA_RECONCILE"
					}, {
						"value": "[]",
						"key": "P2PV2_LISTEN_ADDRESSES"
					}, {
						"value": "6688",
						"key": "CHAINLINK_PORT"
					}, {
						"value": "240h0m0s",
						"key": "REAPER_EXPIRATION"
					}, {
						"value": "-1",
						"key": "REPLAY_FROM_BLOCK"
					}, {
						"value": "/tmp/chainlink_test/gql-test",
						"key": "ROOT"
					}, {
						"value": "true",
						"key": "SECURE_COOKIES"
					}, {
						"value": "2m0s",
						"key": "SESSION_TIMEOUT"
					}, {
						"value": "false",
						"key": "TELEMETRY_INGRESS_LOGGING"
					}, {
						"value": "",
						"key": "TELEMETRY_INGRESS_SERVER_PUB_KEY"
					}, {
						"value": "",
						"key": "TELEMETRY_INGRESS_URL"
					}, {
						"value": "",
						"key": "CHAINLINK_TLS_HOST"
					}, {
						"value": "6689",
						"key": "CHAINLINK_TLS_PORT"
					}, {
						"value": "false",
						"key": "CHAINLINK_TLS_REDIRECT"
					}]
				}
			}`,
		},
	}

	RunGQLTests(t, testCases)
}
