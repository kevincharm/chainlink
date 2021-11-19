package eth_test

import (
	"context"
	"errors"
	"math/big"
	"net/http/httptest"
	"net/url"
	"testing"
	"time"

	"github.com/ethereum/go-ethereum/common/hexutil"
	"github.com/ethereum/go-ethereum/rpc"
	"github.com/pkg/errors"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"
	"github.com/stretchr/testify/require"
	"github.com/tidwall/gjson"
	"go.uber.org/multierr"

	"github.com/smartcontractkit/chainlink/core/internal/cltest"
	"github.com/smartcontractkit/chainlink/core/logger"
	"github.com/smartcontractkit/chainlink/core/services/eth"
	"github.com/smartcontractkit/chainlink/core/services/eth/mocks"
)

func init() {
	eth.DialRetryInterval = 100 * time.Millisecond
}

func TestPool_Dial(t *testing.T) {
	tests := []struct {
		name        string
		presetID    *big.Int
		nodes       []chainIDResps
		sendNodes   []chainIDResp
		expectErr   bool
		multiErrCnt int
	}{
		{
			name: "normal",
			nodes: []chainIDResps{
				{ws: chainIDResp{1, nil}},
			},
			sendNodes: []chainIDResp{
				{1, nil},
			},
		},
		{
			name:     "normal preset",
			presetID: big.NewInt(1),
			nodes: []chainIDResps{
				{ws: chainIDResp{1, nil}},
			},
			sendNodes: []chainIDResp{
				{1, nil},
			},
		},
		{
			name:      "wrong id",
			nodes:     []chainIDResps{{ws: chainIDResp{1, nil}}},
			sendNodes: []chainIDResp{{2, nil}},
			expectErr: true,
		},
		{
			name:      "wrong id preset",
			presetID:  big.NewInt(1),
			nodes:     []chainIDResps{{ws: chainIDResp{1, nil}}},
			sendNodes: []chainIDResp{{2, nil}},
			expectErr: true,
		},
		{
			name:     "wrong id preset multiple",
			presetID: big.NewInt(1),
			nodes: []chainIDResps{
				{ws: chainIDResp{1, nil}, http: &chainIDResp{2, nil}},
				{ws: chainIDResp{3, nil}, http: &chainIDResp{1, nil}},
			},
			sendNodes: []chainIDResp{
				{2, nil},
				{6, nil},
			},
			expectErr:   true,
			multiErrCnt: 4,
		},
		{
			name:      "error",
			nodes:     []chainIDResps{{ws: chainIDResp{1, nil}}},
			sendNodes: []chainIDResp{{-1, errors.New("fake")}},
			expectErr: true,
		},
		{
			name:      "error preset",
			presetID:  big.NewInt(1),
			nodes:     []chainIDResps{{ws: chainIDResp{1, nil}}},
			sendNodes: []chainIDResp{{-1, errors.New("fake")}},
			expectErr: true,
		},
	}
	for _, test := range tests {
		test := test
		t.Run(test.name, func(t *testing.T) {
			ctx, cancel := context.WithTimeout(context.Background(), cltest.DefaultWaitTimeout)
			defer cancel()

			nodes := make([]Node, len(test.nodes))
			for i, n := range test.nodes {
				nodes[i] = n.newNode(t)
			}
			sendNodes := make([]SendOnlyNode, len(test.sendNodes))
			for i, n := range test.sendNodes {
				sendNodes[i] = n.newSendOnlyNode(t)
			}
			p := NewPool(logger.TestLogger(t), nodes, sendNodes, test.presetID)
			if err := p.Dial(ctx); err != nil {
				if test.expectErr {
					if test.multiErrCnt > 0 {
						assert.Equal(t, test.multiErrCnt, len(multierr.Errors(err)))
					}
				} else {
					t.Error(err)
				}
			} else if test.expectErr {
				t.Error("expected error")
			}
		})
	}
}

type chainIDResp struct {
	chainID int64
	err     error
}

func (r *chainIDResp) newSendOnlyNode(t *testing.T) SendOnlyNode {
	httpURL := r.newHTTPServer(t)
	return NewSendOnlyNode(logger.TestLogger(t), *httpURL, t.Name())
}
func (r *chainIDResp) newHTTPServer(t *testing.T) *url.URL {
	rpcSrv := rpc.NewServer()
	t.Cleanup(rpcSrv.Stop)
	rpcSrv.RegisterName("eth", &chainIDService{*r})
	ts := httptest.NewServer(rpcSrv)
	t.Cleanup(ts.Close)

	httpURL, err := url.Parse(ts.URL)
	require.NoError(t, err)
	return httpURL
}

type chainIDResps struct {
	ws   chainIDResp
	http *chainIDResp
}

func (r *chainIDResps) newNode(t *testing.T) Node {
	ws := cltest.NewWSServer(t, big.NewInt(r.ws.chainID), func(method string, params gjson.Result) (string, string) {
		t.Errorf("Unexpected method call: %s(%s)", method, params)
		return "", ""
	})

	wsURL, err := url.Parse(ws)
	require.NoError(t, err)

	var httpURL *url.URL
	if r.http != nil {
		httpURL = r.http.newHTTPServer(t)
	}

	return NewNode(logger.TestLogger(t), *wsURL, httpURL, t.Name())
}

type chainIDService struct {
	chainIDResp
}

func (x *chainIDService) ChainId(ctx context.Context) (*hexutil.Big, error) {
	if x.err != nil {
		return nil, x.err
	}
	return (*hexutil.Big)(big.NewInt(x.chainID)), nil
}

func newPool(t *testing.T, nodes []eth.Node) *eth.Pool {
	return eth.NewPool(logger.TestLogger(t), nodes, []eth.SendOnlyNode{}, &cltest.FixtureChainID)
}

func TestPool_Dial(t *testing.T) {
	t.Run("starts and kicks off retry loop even if dial errors", func(t *testing.T) {
		node := new(mocks.Node)
		node.On("String").Return("n2")
		node.On("Close").Maybe()
		node.Test(t)
		nodes := []eth.Node{node}
		p := newPool(t, nodes)

		node.On("Dial", mock.Anything).Return(errors.New("error"))
		// TODO: Test verification error?
		// node.On("Verify", mock.Anything, &cltest.FixtureChainID).Return(nil)

		err := p.Dial(context.Background())
		require.NoError(t, err)

		p.Close()

		node.AssertExpectations(t)
	})

}

func TestPool_RunLoop(t *testing.T) {
	t.Run("with several nodes and dial errors", func(t *testing.T) {
		n1 := new(mocks.Node)
		n1.Test(t)
		n2 := new(mocks.Node)
		n2.Test(t)
		nodes := []eth.Node{n1, n2}
		p := newPool(t, nodes)

		n1.On("String").Maybe().Return("n1")
		n2.On("String").Maybe().Return("n2")

		n1.On("Close").Maybe()
		n2.On("Close").Maybe()

		wait := make(chan struct{})
		// n1 succeeds
		n1.On("Dial", mock.Anything).Return(nil).Once()
		n1.On("State").Return(eth.NodeStateAlive)
		// n2 fails once then succeeds in runloop
		n2.On("Dial", mock.Anything).Return(errors.New("first error")).Once()
		n2.On("State").Return(eth.NodeStateDead)
		n2.On("Dial", mock.Anything).Once().Return(nil).Run(func(_ mock.Arguments) {
			close(wait)
		})
		// Handle spurious extra calls after
		n2.On("Dial", mock.Anything).Maybe()

		require.NoError(t, p.Dial(context.Background()))

		select {
		case <-wait:
		case <-time.After(5 * time.Second):
			t.Fatal("timed out waiting for Dial call")
		}
		p.Close()

		n1.AssertExpectations(t)
		n2.AssertExpectations(t)
	})

}
