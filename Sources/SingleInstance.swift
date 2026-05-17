import Foundation

// Single instance lock using file lock
class SingleInstance {
    private var fileDescriptor: Int32 = -1

    func tryLock() -> Bool {
        fileDescriptor = open(Constants.IPC.lockFilePath, O_CREAT | O_RDWR, 0o644)
        if fileDescriptor == -1 { return false }

        var lock = flock()
        lock.l_start = 0
        lock.l_len = 0
        lock.l_type = Int16(F_WRLCK)
        lock.l_whence = Int16(SEEK_SET)

        if fcntl(fileDescriptor, F_SETLK, &lock) == -1 {
            close(fileDescriptor)
            fileDescriptor = -1
            return false
        }

        // Write PID to file
        ftruncate(fileDescriptor, 0)
        let pid = "\(getpid())"
        write(fileDescriptor, pid, pid.count)

        return true
    }

    deinit {
        if fileDescriptor != -1 {
            close(fileDescriptor)
            unlink(Constants.IPC.lockFilePath)
        }
    }
}

let singleInstance = SingleInstance()
