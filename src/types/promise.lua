export type PromiseLike<T> = {
	andThen: (
		self: PromiseLike<T>,
		resolve: ((T) -> ...(nil | T | PromiseLike<T>))?,
		reject: ((any) -> ...(nil | T | PromiseLike<T>))?
	) -> PromiseLike<T>,
}

type PromiseStatus = "Started" | "Resolved" | "Rejected" | "Cancelled"

export type Promise<T> = {
	andThen: (
		self: Promise<T>,
		resolve: ((T) -> ...(nil | T | PromiseLike<T>))?,
		reject: ((any) -> ...(nil | T | PromiseLike<T>))?
	) -> Promise<T>,

	catch: (Promise<T>, ((any) -> ...(nil | T | PromiseLike<nil>))) -> Promise<T>,

	onCancel: (Promise<T>, () -> ()?) -> boolean,

	expect: (Promise<T>) -> ...T,
	cancel: (Promise<T>) -> nil,

	await: (Promise<T>) -> (boolean, ...(T | any)),
	getStatus: (self: Promise<T>) -> PromiseStatus,
	awaitStatus: (self: Promise<T>) -> (PromiseStatus, ...(T | any)),
}

return nil
