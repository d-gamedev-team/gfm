module gfm.core.lockedqueue;

import core.sync.mutex,
       core.sync.semaphore;

import gfm.core.queue;

// Locked queue for inter-thread communication
// relies on Queue
// support multiple writers, multiple readers
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

        size_t capacity() const
        {
            // no lock-required as capacity does not change
            return _queue.capacity;
        }

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

        T popFront()
        {
            _readerSemaphore.wait();
            _rwMutex.lock();
            T res = _queue.popFront();
            _rwMutex.unlock();
            _writerSemaphore.notify();
            return res;
        }

        T popBack()
        {
            _readerSemaphore.wait();
            _rwMutex.lock();
            T res = _queue.popBack();
            _rwMutex.unlock();
            _writerSemaphore.notify();
            return res;
        }

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

