crate::veiled_f! {
    min_bet => 10.0,
    bet_step => 10.0,
    starting_balance => 100_000.0,
    starting_bet => 100.0,
    // Slack when comparing a bet against the balance so a bet equal to the
    // balance after cent rounding still goes through.
    place_slack => 0.001,
}

pub fn money(value: f64) -> f64 {
    (value * 100.0).round() / 100.0
}

pub fn opening_balance(value: f64) -> f64 {
    if value < 0.0 { 0.0 } else { value }
}

pub fn is_broke(balance: f64) -> bool {
    balance < min_bet()
}

pub fn fit_bet(value: f64, balance: f64) -> f64 {
    if is_broke(balance) {
        return money(balance);
    }
    let mut next = value;
    if next < min_bet() {
        next = min_bet();
    }
    if next > balance {
        next = balance;
    }
    money(next)
}

pub fn nudge_bet(bet: f64, direction: i32, balance: f64) -> f64 {
    let step = bet_step();
    let units = bet / step;
    let next = if direction > 0 {
        units.floor() * step + step
    } else {
        units.ceil() * step - step
    };
    fit_bet(next, balance)
}

pub fn double_bet(bet: f64, balance: f64) -> f64 {
    fit_bet(bet * 2.0, balance)
}

pub fn can_place(bet: f64, balance: f64) -> bool {
    !is_broke(balance) && bet >= min_bet() && bet <= balance + place_slack()
}

pub fn debit(balance: f64, amount: f64) -> f64 {
    money(balance - amount)
}

pub fn credit(balance: f64, amount: f64) -> f64 {
    money(balance + amount)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn constants_decode_cleanly() {
        assert_eq!(min_bet(), 10.0);
        assert_eq!(starting_balance(), 100_000.0);
        assert_eq!(starting_bet(), 100.0);
    }

    #[test]
    fn bet_snaps_to_steps() {
        assert_eq!(nudge_bet(100.0, 1, 1000.0), 110.0);
        assert_eq!(nudge_bet(105.0, 1, 1000.0), 110.0);
        assert_eq!(nudge_bet(105.0, -1, 1000.0), 100.0);
        assert_eq!(nudge_bet(10.0, -1, 1000.0), 10.0);
        assert_eq!(nudge_bet(990.0, 1, 995.5), 995.5);
    }

    #[test]
    fn bet_stays_inside_wallet() {
        assert_eq!(fit_bet(5.0, 1000.0), 10.0);
        assert_eq!(fit_bet(5000.0, 1000.0), 1000.0);
        assert_eq!(fit_bet(50.0, 7.456), 7.46);
        assert_eq!(double_bet(600.0, 1000.0), 1000.0);
    }

    #[test]
    fn placing_requires_funds() {
        assert!(can_place(10.0, 10.0));
        assert!(!can_place(10.0, 9.99));
        assert!(!can_place(9.0, 100.0));
        assert!(!can_place(100.01, 100.0));
    }

    #[test]
    fn wallet_moves_in_cents() {
        assert_eq!(debit(100.0, 33.333), 66.67);
        assert_eq!(credit(0.1, 0.2), 0.3);
        assert_eq!(opening_balance(-5.0), 0.0);
    }
}
