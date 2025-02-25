// https://github.com/bluesky-social/atproto/blob/main/packages/pds/src/config/env.ts

package main

import (
	"context"
	"flag"
	"io"
	"log/slog"
	"os"
	"path/filepath"
	"strings"

	v1 "k8s.io/api/core/v1"
	"k8s.io/apimachinery/pkg/api/errors"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/client-go/kubernetes"
	corev1 "k8s.io/client-go/kubernetes/typed/core/v1"
	restclient "k8s.io/client-go/rest"
	"k8s.io/client-go/tools/clientcmd"
)

type Flags struct {
	namespace  string
	secretName string
}

func main() {
	flags := Flags{secretName: "generated-credentials"}
	flag.StringVar(&flags.namespace, "n", flags.namespace, "default namespace to use")
	flag.StringVar(&flags.secretName, "secret", flags.secretName, "name of the secret that credentials are stored")
	flag.Parse()
	logger := slog.Default()
	k8sconfig, err := k8sConfig()
	if err != nil {
		logger.Error(err.Error())
		os.Exit(1)
	}
	clientset, err := kubernetes.NewForConfig(k8sconfig)
	if err != nil {
		logger.Error(err.Error())
		os.Exit(1)
	}
	if len(flags.namespace) == 0 {
		flags.namespace = readNamespaceOr("default")
	}

	secrets := clientset.CoreV1().Secrets(flags.namespace)
	ctx := context.Background()
	if !secretExists(ctx, secrets, flags.secretName) {
		secret, err := secrets.Create(ctx, &v1.Secret{
			TypeMeta: metav1.TypeMeta{
				APIVersion: "v1",
				Kind:       "Secret",
			},
			ObjectMeta: metav1.ObjectMeta{
				Name:      flags.secretName,
				Namespace: flags.namespace,
			},
		}, metav1.CreateOptions{})
		if err != nil {
			logger.Error("failed to create new secret", slog.Any("error", err))
			os.Exit(1)
		}
		_ = secret
	}
}

func secretExists(
	ctx context.Context,
	secrets corev1.SecretInterface,
	name string,
) bool {
	_, err := secrets.Get(ctx, name, metav1.GetOptions{})
	if err != nil {
		if errors.IsNotFound(err) {
			return false
		}
		return false
	} else {
		return true
	}
}

func k8sConfig() (*restclient.Config, error) {
	f := filepath.Join(os.Getenv("HOME"), ".kube", "config")
	if !exists(f) {
		f = "" // will resolve to rest.InClusterConfig()
	}
	return clientcmd.BuildConfigFromFlags("", f)
}

func readNamespaceOr(defValue string) string {
	f, err := os.Open("/var/run/secrets/kubernetes.io/serviceaccount/namespace")
	if err != nil {
		return defValue
	}
	defer f.Close()
	b, err := io.ReadAll(f)
	if err != nil {
		return defValue
	}
	return strings.Trim(string(b), " \n\t")
}

func exists(name string) bool {
	_, err := os.Stat(name)
	return !os.IsNotExist(err)
}
