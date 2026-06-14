#!/usr/bin/env python3
"""Render a KMS topology diagram from a Terraform plan JSON.

Shows the KMS key + alias as the centre, with edges to the administrator
principals (manage), user principals (encrypt/decrypt), and AWS service
principals (gated by kms:ViaService). The "manage" / "use" / "via-service"
edges are styled differently so the policy shape is readable at a glance.

Usage:
    python scripts/render-architecture.py <plan.json> <output-path-no-ext>
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

from diagrams import Cluster, Diagram, Edge
from diagrams.aws.compute import EC2, ECS, Lambda
from diagrams.aws.database import RDS
from diagrams.aws.general import Users
from diagrams.aws.management import Cloudwatch
from diagrams.aws.security import IAMRole, KMS
from diagrams.aws.storage import S3


def load_resources(plan_path: Path) -> list[dict]:
    plan = json.loads(plan_path.read_text())
    root = plan.get("planned_values", {}).get("root_module", {})
    collected: list[dict] = []

    def walk(mod: dict) -> None:
        for r in mod.get("resources", []):
            collected.append(r)
        for child in mod.get("child_modules", []):
            walk(child)

    walk(root)
    return collected


SERVICE_ICON = {
    "s3.amazonaws.com": S3,
    "logs.amazonaws.com": Cloudwatch,
    "rds.amazonaws.com": RDS,
    "lambda.amazonaws.com": Lambda,
    "ec2.amazonaws.com": EC2,
    "ecs.amazonaws.com": ECS,
    "ecs-tasks.amazonaws.com": ECS,
}


def _service_icon(service_principal: str):
    """Return the right icon for a service principal, falling back to KMS."""
    # Handle region-scoped principals like "logs.ap-south-1.amazonaws.com"
    for key, icon in SERVICE_ICON.items():
        bare = key.split(".")[0] + "."  # "s3." / "logs." / etc.
        if service_principal.startswith(bare):
            return icon
    return Cloudwatch  # generic-ish fallback


def _short_principal(arn: str) -> str:
    """arn:aws:iam::111122223333:role/devotica-prod-app → role/devotica-prod-app"""
    if "::" not in arn:
        return arn
    tail = arn.split("::", 1)[1]
    parts = tail.split(":", 1)
    return parts[1] if len(parts) > 1 else tail


def render(plan_path: Path, out_no_ext: Path) -> None:
    resources = load_resources(plan_path)

    keys = [r for r in resources if r["type"] == "aws_kms_key"]
    aliases = [r for r in resources if r["type"] == "aws_kms_alias"]
    if not keys:
        raise SystemExit("No aws_kms_key resource found in plan — nothing to render.")

    key_v = keys[0].get("values", {}) or {}
    description = key_v.get("description") or "KMS key"
    multi_region = bool(key_v.get("multi_region"))
    rotation = bool(key_v.get("enable_key_rotation"))

    alias_v = (aliases[0].get("values", {}) if aliases else {}) or {}
    alias_name = alias_v.get("name") or "alias/?"

    # Parse the key policy to get administrators / users / service principals.
    administrators: list[str] = []
    users: list[str] = []
    service_principals: list[str] = []
    try:
        policy = json.loads(key_v.get("policy") or "{}")
        for stmt in policy.get("Statement", []) or []:
            sid = stmt.get("Sid") or ""
            principal = stmt.get("Principal", {}) or {}
            aws = principal.get("AWS", [])
            if isinstance(aws, str):
                aws = [aws]
            svc = principal.get("Service", [])
            if isinstance(svc, str):
                svc = [svc]

            if sid == "AllowKeyAdministration":
                administrators.extend(aws)
            elif sid == "AllowKeyUsage":
                users.extend(aws)
            elif sid.startswith("AllowService_"):
                service_principals.extend(svc)
    except json.JSONDecodeError:
        pass

    graph_attr = {
        "fontsize": "20",
        "splines": "ortho",
        "ranksep": "0.9",
        "nodesep": "0.45",
        "pad": "0.5",
    }
    title_bits = [alias_name]
    if multi_region:
        title_bits.append("multi-region")
    if rotation:
        title_bits.append("rotation on")
    title = " · ".join(title_bits)

    out_no_ext.parent.mkdir(parents=True, exist_ok=True)
    with Diagram(
        f"terraform-aws-kms — {title}",
        filename=str(out_no_ext),
        show=False,
        direction="LR",
        outformat="png",
        graph_attr=graph_attr,
    ):
        with Cluster(alias_name):
            key_node = KMS(f"{alias_name}\n{description[:50]}")

            if administrators:
                with Cluster("Administrators"):
                    for arn in administrators:
                        admin = IAMRole(_short_principal(arn))
                        admin >> Edge(label="manage", style="dashed") >> key_node

            if users:
                with Cluster("Users (encrypt/decrypt)"):
                    for arn in users:
                        u = IAMRole(_short_principal(arn))
                        u >> Edge(label="use") >> key_node

            if service_principals:
                with Cluster("Service principals (kms:ViaService)"):
                    for svc in service_principals:
                        Icon = _service_icon(svc)
                        s = Icon(svc.split(".")[0])
                        s >> Edge(label="ViaService", style="dotted") >> key_node


def main() -> None:
    if len(sys.argv) < 3:
        sys.stderr.write(
            "Usage: render-architecture.py <plan.json> <output-path-without-ext>\n"
        )
        sys.exit(2)
    render(Path(sys.argv[1]), Path(sys.argv[2]))


if __name__ == "__main__":
    main()
