module gfm.core.lockedqueue;

import core.sync.mutex,
       core.sync.semaphore;

import gfm.core.queue;

/**
    Locked queue for inter-thread communication.
    Support multiple writers, multiple readers.
    Blocks threads either when empty or full.

    See_also: $(LINK2 gfm.core.queue.html, Queue)
 */
final class LockedQueue(T)
{
    public
    {
        this(size_t capacity)
        {
            _queue = new Queue!T(capacity);
            _rwMutex = new Mutex();
            _readerSemaphore = new Semaphore(0);
            _writerSemaphore = new Semaphore(capacity);
        }

        /// Returns: Capacity of the locked queue.
        size_t capacity() const
        {
            // no lock-required as capacity does not change
            return _queue.capacity;
        }

        /// Push an item to the back, block if queue is full.
        void pushBack(T x)
        {
            _writerSemaphore.wait();
            {
                _rwMutex.lock();
                _queue.pushBack(x);
                _rwMutex.unlock();
            }
            _readerSemaphore.notify();
        }

        /// Push an item to the front, block if queue is full.
        void pushFront(T x)
        {
            _writerSemaphore.wait();
            {
                _rwMutex.lock();
                _queue.pushFront(x);
                _rwMutex.unlock();
            }
            _readerSemaphore.notify();
        }

        /// Pop an item from the front, block if queue is empty.
        T popFront()
        {
            _readerSemaphore.wait();
            _rwMutex.lock();
            T res = _queue.popFront();
            _rwMutex.unlock();
            _writerSemaphore.notify();
            return res;
        }

        /// Pop an item from the back, block if queue is empty.
        T popBack()
        {
            _readerSemaphore.wait();
            _rwMutex.lock();
            T res = _queue.popBack();
            _rwMutex.unlock();
            _writerSemaphore.notify();
            return res;
        }

        /// Removes all locked queue items.
        void clear()
        {
            while (_readerSemaphore.tryWait())
            {
                _rwMutex.lock();
                _queue.popBack();
                _rwMutex.unlock();
                _writerSemaphore.notify();
            }
        }
    }

    private
    {
        Queue!T _queue;
        Mutex _rwMutex;
        Semaphore _readerSemaphore, _writerSemaphore;
    }
}

