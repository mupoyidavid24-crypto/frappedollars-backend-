from backend.trade_identity import make_broker_comment, make_magic_number, make_trade_tag, normalize_trade_id


def run() -> None:
    cases = [
        "abc-123",
        "  ABC-123  ",
        "trade-001",
        "trade  with   spaces",
    ]

    expected_equal_groups = [
        ("abc-123", "  ABC-123  "),
    ]

    values: dict[str, tuple[str, int, str]] = {}
    for trade_id in cases:
        values[trade_id] = (
            make_trade_tag(trade_id),
            make_magic_number(trade_id),
            make_broker_comment(trade_id),
        )

    for left, right in expected_equal_groups:
        assert normalize_trade_id(left) == normalize_trade_id(right)
        assert values[left][0] == values[right][0]
        assert values[left][1] == values[right][1]
        assert values[left][2] == values[right][2]

    for trade_id, (tag, magic, comment) in values.items():
        assert len(tag) == 13
        assert all(ch in "0123456789abcdefghijklmnopqrstuvwxyz" for ch in tag)
        assert comment == f"FRP|v1|t={tag}"
        assert 0 <= magic <= 2_147_483_647
        print(f"{trade_id!r} => tag={tag} magic={magic} comment={comment}")


if __name__ == "__main__":
    run()