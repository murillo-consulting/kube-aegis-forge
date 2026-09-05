# /// script
# requires-python = ">=3.13"
# dependencies = ["PyYAML==6.0.3"]
# ///
"""Render the pinned controller and verify the cross-chart ingress contract."""

import argparse
import copy
import json
import subprocess
import tempfile
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[1]


def read(path):
    return yaml.safe_load((ROOT / path).read_text())


def render(args):
    return subprocess.check_output(["helm", "template", *args], cwd=ROOT, text=True)


def resource(documents, kind, name):
    return next(
        d
        for d in yaml.safe_load_all(documents)
        if d and d["kind"] == kind and d["metadata"]["name"] == name
    )


def check(output):
    app = read("platform/argocd/common/10-traefik.yaml")
    source = app["spec"]["source"]
    values = source["helm"]["valuesObject"]
    output.mkdir(parents=True, exist_ok=True)
    values_path = output / "traefik-values.yaml"
    values_path.write_text(yaml.safe_dump(values))
    controller = render(
        [
            "traefik",
            source["chart"],
            "--repo",
            source["repoURL"],
            "--version",
            str(source["targetRevision"]),
            "--namespace",
            "traefik",
            "--values",
            str(values_path),
        ]
    )
    (output / "traefik.yaml").write_text(controller)
    service = resource(controller, "Service", "traefik")["spec"]
    ports = service["ports"]
    assert service["type"] == "NodePort"
    assert [(p["name"], p["nodePort"]) for p in ports] == [("web", 30080)]
    cluster = read("platform/kind/cluster.yaml")
    assert cluster["nodes"][0]["extraPortMappings"][0]["containerPort"] == ports[0]["nodePort"]
    test_cluster = copy.deepcopy(cluster)
    test_cluster["nodes"] = test_cluster["nodes"][:1]
    test_cluster["nodes"][0]["extraPortMappings"][0]["hostPort"] = 18080
    (output / "kind.yaml").write_text(yaml.safe_dump(test_cluster))
    ingress_class = resource(controller, "IngressClass", "traefik")
    assert ingress_class["spec"]["controller"] == "traefik.io/ingress-controller"
    assert (
        ingress_class["metadata"]
        .get("annotations", {})
        .get("ingressclass.kubernetes.io/is-default-class")
        != "true"
    )
    deployment = resource(controller, "Deployment", "traefik")["spec"]
    pod = deployment["template"]["spec"]
    container = pod["containers"][0]
    assert "@sha256:" in container["image"]
    assert deployment["replicas"] == 2
    assert pod["securityContext"]["runAsNonRoot"]
    assert container["securityContext"]["capabilities"]["drop"] == ["ALL"]
    args = container["args"]
    assert "--api.dashboard=false" in args and "--api.insecure=false" in args
    assert "--providers.kubernetesingress.namespaces=demo" in args
    assert not any(
        a.startswith(("--providers.kubernetescrd", "--providers.kubernetesgateway")) for a in args
    )
    chart = read("platform/charts/demo-api/Chart.yaml")
    for environment in ("local", "aws"):
        workload = read(f"platform/argocd/{environment}/30-demo-api.yaml")
        helm_source = workload["spec"]["sources"][0]
        assert str(helm_source["targetRevision"]) == str(chart["version"])
        override = output / f"{environment}-values.yaml"
        override.write_text(json.dumps(helm_source["helm"]["valuesObject"]))
        manifests = render(
            [
                "demo-api",
                "platform/charts/demo-api",
                "--namespace",
                "demo",
                "--values",
                str(override),
            ]
        )
        (output / f"{environment}.yaml").write_text(manifests)
        policy = resource(manifests, "NetworkPolicy", "demo-api-allowed-flows")
        peers = policy["spec"]["ingress"][0]["from"]
        namespaces = [
            p["namespaceSelector"]["matchLabels"]["kubernetes.io/metadata.name"] for p in peers
        ]
        assert namespaces == ["traefik", "monitoring"]
        if environment == "local":
            ingress = resource(manifests, "Ingress", "demo-api")
            assert ingress["spec"]["ingressClassName"] == "traefik"
        else:
            assert not any(d and d["kind"] == "Ingress" for d in yaml.safe_load_all(manifests))
    print(
        "Ingress contract passed: image, ports, local/AWS routes and policy peers"
    )


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path)
    options = parser.parse_args()
    if options.output:
        check(options.output.resolve())
    else:
        with tempfile.TemporaryDirectory(prefix="aegis-ingress-") as directory:
            check(Path(directory))
