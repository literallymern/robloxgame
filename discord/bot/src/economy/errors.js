// An error whose message is safe to show to the player who triggered it.
export class UserError extends Error {
  constructor(message) {
    super(message);
    this.name = 'UserError';
    this.userFacing = true;
  }
}

export class InsufficientFundsError extends UserError {
  constructor(message = 'Insufficient funds.') {
    super(message);
    this.name = 'InsufficientFundsError';
  }
}

export class PermissionError extends UserError {
  constructor(message = 'You are not authorised to do this.') {
    super(message);
    this.name = 'PermissionError';
  }
}
